require 'yaml'

class AcceptOverseerJob
  include Sidekiq::Job
  include Sidekiq::Status::Worker
  include LogHelper
  include ApplicationHelper
  include FileHelper

  sidekiq_options lock: :until_executed,
                  # TODO: should students be allowed to submit a new task submission when the previous overseer job has not started/completed?
                  lock_args_method: ->(args) { [args.first, 'overseer-assessment'] },
                  on_conflict: :reject,
                  retry: 1

  def perform(task_id, _output_path, docker_image_name_tag, submission, assessment, timestamp, overseer_assessment_id)
    logger.info "Starting overseer job..."

    at(0)
    total(1)

    task = Task.find(task_id)

    work_dir_name = "#{task.id}-#{overseer_assessment_id}"

    work_dir = Rails.root.join("tmp", "overseer", work_dir_name)
    FileUtils.mkdir_p(work_dir)

    raise "PDF is still compiling" if task.processing_pdf? || !task.has_done_file?

    raise "Submission file not found: #{submission}" unless File.exist?(submission)

    # Extract submission files, removing any parent folders
    Zip::File.open(submission) do |zip_file|
      zip_file.each do |entry|
        next if entry.name_is_directory?

        parts = entry.name.split('/')[1..]
        next unless parts.length >= 1

        file_name = parts.first
        index = file_name.to_i

        file = task.upload_requirements[index]
        final_name = file['name']

        dest_path = File.join(work_dir, final_name)
        FileUtils.mkdir_p(File.dirname(dest_path))
        zip_file.extract(entry, dest_path) { true }
      end
    end

    # Extract optional assessment resources
    if File.exist?(assessment)
      Zip::File.open(assessment) do |zip_file|
        zip_file.each do |entry|
          dest_path = File.join(work_dir, entry.name)
          FileUtils.mkdir_p(File.dirname(dest_path))
          zip_file.extract(entry, dest_path) { true } # overwrite if exists
        end
      end
    end

    # Extract execution script
    script_path = task.task_definition.task_assessment_script
    raise "No execution script found" unless File.exist?(script_path)

    script_contents = File.read(script_path)
    raise "Execution script is empty" if script_contents.blank?

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
      bash -c "cd /overseer/work-dir/#{work_dir_name} && ./run.sh"
    )

    system(command)

    yaml_path = File.join(work_dir, 'output.yaml')

    oa = OverseerAssessment.find(overseer_assessment_id)

    oa.update_from_output(work_dir)
    if File.exist?(yaml_path)
      path = FileHelper.task_submission_identifier_path_with_timestamp(:done, task, timestamp)
      FileUtils.cp(yaml_path, path)
      FileUtils.rm_rf(work_dir)
    end

    logger.info "Completed overseer job"
  rescue StandardError => e
    logger.error e
    raise e
  end
end
