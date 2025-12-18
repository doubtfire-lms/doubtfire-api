require 'yaml'
require 'open3'

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
    task_definition = task.task_definition

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

    overseer_steps = task_definition.overseer_steps

    # Extract execution script
    # script_path = task.task_definition.task_assessment_script
    # raise "No execution script found" unless File.exist?(script_path)

    # system(command)
    #

    # TODO: create an assessment comment that shows "Tests in progress..."

    success_status = nil
    failure_status = nil

    overseer_steps.each do |step|
      # script_contents = File.read(script_path)
      script_contents = step.run_command
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
                       "-v #{mount}/#{work_dir_name}:/overseer/work-dir/#{work_dir_name}"
                     end

      container_name = "overseer-#{task_id}-#{timestamp}"

      command = %(
        timeout 300 docker run --rm -i \
        --cpus 1 \
        --network none \
        #{volume_mount} \
        --name #{container_name} \
        #{docker_image_name_tag} \
        bash -c "cd /overseer/work-dir/#{work_dir_name} && ./run.sh"
      )

      output = ""
      status = nil

      stdin_input_file = nil
      expected_output_file = nil
      if step.step_type == 'output_diff'
        stdin_input_file = step.stdin_input_file.present? ? File.join(work_dir, step.stdin_input_file) : nil
        expected_output_file = step.expected_output_file.present? ? File.join(work_dir, step.expected_output_file) : nil
      end

      stdin_contents = nil
      expected_output_contents = nil

      Open3.popen2e(command) do |stdin, stdout_err, wait_thr|
        if stdin_input_file && File.exist?(stdin_input_file)
          File.open(stdin_input_file, 'rb') { |f| IO.copy_stream(f, stdin) }
          stdin_contents = File.read(stdin_input_file)
          stdin.close
        end

        stdout_err.each { |line| output << line }
        status = wait_thr.value
      end

      pass = true

      if status.exitstatus != 0
        pass = false
      end

      if step.step_type == 'output_diff'
        expected_output = File.read(expected_output_file)
        expected_output_contents = expected_output
        if step.partial_output_diff
          unless output.include?(expected_output)
            pass = false
          end
        elsif output != expected_output
          pass = false
        end
      end

      puts "Test passed?: #{[pass]}"

      stdout_sha256 = Digest::SHA256.hexdigest(output)
      stdin_sha256 = stdin_contents && Digest::SHA256.hexdigest(stdin_contents)
      expected_sha256 = expected_output_contents && Digest::SHA256.hexdigest(expected_output_contents)

      OverseerStepResult.create!({
                                   overseer_assessment_id: overseer_assessment_id,
                                   overseer_step: step,
                                   exit_status: status.exitstatus,
                                   pass: pass,
                                   stdout: output,
                                   stdin: stdin_contents,
                                   expected_output: expected_output_contents,
                                   stdout_sha256: stdout_sha256,
                                   stdin_sha256: stdin_sha256,
                                   expected_output_sha256: expected_sha256
                                 })

      byebug

      if !pass && step.halt_on_failure
        break
      end
    end

    # yaml_path = File.join(work_dir, 'output.yaml')

    oa = OverseerAssessment.find(overseer_assessment_id)

    # TODO: update assessment comment with "View Overseer Report"

    # oa.update_from_output(work_dir)
    # if File.exist?(yaml_path)
    #   path = FileHelper.task_submission_identifier_path_with_timestamp(:done, task, timestamp)
    #   FileUtils.cp(yaml_path, path)
    #   FileUtils.rm_rf(work_dir)
    # end

    logger.info "Completed overseer job"
  rescue StandardError => e
    logger.error e
    raise e
  end
end
