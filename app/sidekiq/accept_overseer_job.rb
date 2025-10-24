require 'yaml'

class AcceptOverseerJob
  include Sidekiq::Job
  include Sidekiq::Status::Worker
  include LogHelper
  include ApplicationHelper
  include FileHelper

  sidekiq_options lock: :until_executed,
                  # TODO: should students be allowed to submit a new task submission when the previous overseer job has not started/completed?
                  lock_args_method: ->(args) { [args.first] },
                  on_conflict: :reject
  # retry: 5

  def perform(task_id, output_path, docker_image_name_tag, submission, assessment, timestamp, overseer_assessment_id)
    logger.info "Starting overseer job..."

    message = {
      output_path: output_path,
      docker_image_name_tag: docker_image_name_tag,
      submission: submission,
      assessment: assessment,
      timestamp: timestamp,
      task_id: task_id,
      overseer_assessment_id: overseer_assessment_id,
      zip_file: 1
    }

    # Example message data

    # {
    #   output_path: "/student-work/submission_history/COS10001-1/student_0/done/3/1761090610",
    #   docker_image_name_tag: "doubtfire-deploy_devcontainer-overseer-volumes:latest",
    #   submission: "/student-work/submission_history/COS10001-1/student_0/done/3/1761090610/submission.zip",
    #   assessment: "/student-work/COS10001-1/TaskFiles/1.1P-assessment.zip",
    #   timestamp: "1761090610",
    #   task_id: 3,
    #   overseer_assessment_id: 7,
    #   zip_file: 1
    # }

    work_dir = Rails.root.join("tmp", "overseer", task_id.to_s)
    FileUtils.mkdir_p(work_dir)

    task = Task.find(task_id)

    raise "PDF is still compiling" if task.processing_pdf? || !task.has_done_file?

    # Extract submission files, removing any parent folders
    Zip::File.open(submission) do |zip_file|
      zip_file.each do |entry|
        next if entry.name_is_directory?

        parts = entry.name.split('/')[1..]
        next unless parts

        dest_path = File.join(work_dir, *parts)
        FileUtils.mkdir_p(File.dirname(dest_path))
        zip_file.extract(entry, dest_path) { true }
      end
    end

    # Extract assessment resources
    Zip::File.open(assessment) do |zip_file|
      zip_file.each do |entry|
        dest_path = File.join(work_dir, entry.name)
        FileUtils.mkdir_p(File.dirname(dest_path))
        zip_file.extract(entry, dest_path) { true } # overwrite if exists
      end
    end

    # Extract execution script
    script_path = task.task_definition.task_assessment_script
    script_contents = File.read(script_path)
    run_sh_path = File.join(work_dir, 'run.sh')

    File.write(run_sh_path, script_contents)

    system("chmod +x #{work_dir}/run.sh")

    mount = Doubtfire::Application.config.overseer_workdir_volume_mount
    volume_mount = if mount.nil?
                     # Fallback for development only — mounts the entire overseer container volume,
                     # allowing all task work directories to be accessible. This should never be
                     # used in production, as it breaks isolation between tasks.
                     "--volumes-from #{Doubtfire::Application.config.overseer_fallback_volume_container}"
                   else
                     "-v #{mount}/#{task_id}:/overseer/work-dir/#{task_id}"
                   end

    container_name = "overseer-#{task_id}-#{timestamp}"

    command = %(
      timeout 300 docker run --rm \
      --cpus 1 \
      --network none \
      #{volume_mount} \
      --name #{container_name} \
      #{docker_image_name_tag} \
      bash -c "cd /overseer/work-dir/#{task_id} && ./run.sh"
    )

    system(command)

    yaml_path = File.join(work_dir, 'output.yml')
    yaml_data = YAML.load_file(yaml_path)

    status  = yaml_data['status'].to_s
    message = yaml_data['message'].to_s

    project = task.project
    tutor = project.tutor_for(task.task_definition)

    unless status.nil? || status == "nil"
      if status == 'fix_and_resubmit'
        task.add_text_comment(tutor, "**Automated Comment**: <pre>#{message}</pre>")
      end
      task.trigger_transition(trigger: status, by_user: tutor)
    end

    if status.nil? || status == "nil"
      status = task.task_status.status_key
    end

    output_path = File.join(work_dir, 'output.yml')
    path = FileHelper.task_submission_identifier_path_with_timestamp(:done, task, timestamp)
    FileUtils.cp(output_path, path)

    at(0)
    total(1)

    oa = OverseerAssessment.find(overseer_assessment_id)
    oa.update(
      status: :done,
      result_task_status: status
    )

    FileUtils.rm_rf(work_dir)

    logger.info "Completed overseer job"
  rescue StandardError => e
    logger.error e
    raise e
  end
end
