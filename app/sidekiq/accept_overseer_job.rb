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
                  on_conflict: :reject,
                  retry: false

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
    # TODO: allow run.sh editable directly from within OnTrack
    # Zip::File.open(assessment) do |zip_file|
    #   zip_file.each do |entry|
    #     dest_path = File.join(work_dir, entry.name)
    #     FileUtils.mkdir_p(File.dirname(dest_path))
    #     zip_file.extract(entry, dest_path) { true } # overwrite if exists
    #   end
    # end
    script_path = task.task_definition.task_assessment_script
    script_contents = File.read(script_path)
    run_sh_path = File.join(work_dir, 'run.sh')

    File.write(run_sh_path, script_contents)

    system("chmod +x #{work_dir}/run.sh")

    command = %(
      timeout 300 docker run --rm \
      --cpus 1 \
      --network none \
      --volumes-from doubtfire-overseer \
      doubtfire-deploy_devcontainer-overseer-volumes:latest \
      bash -c "cd /overseer/work-dir/#{task_id} && ./run.sh"
    )

    system(command)

    yaml_path = File.join(work_dir, 'output.yml')
    yaml_data = YAML.load_file(yaml_path)

    status  = yaml_data['status'].to_s
    message = yaml_data['message'].to_s

    project = task.project
    tutor = project.tutor_for(task.task_definition)
    task.add_text_comment(tutor, "**Automated Comment**: #{message}")
    task.trigger_transition(trigger: status, by_user: tutor)

    at(0)
    total(1)

    oa = OverseerAssessment.find(overseer_assessment_id)
    oa.update(
      status: :done,
      result_task_status: message
    )

    logger.info "Completed overseer job"
  rescue StandardError => e
    logger.error e
    raise e
  end
end
