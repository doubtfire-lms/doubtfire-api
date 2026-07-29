require 'yaml'
require 'open3'

class AcceptOverseerJob
  include Sidekiq::Job
  include Sidekiq::Status::Worker
  include LogHelper
  include ApplicationHelper
  include FileHelper

  sidekiq_options lock: :until_executed,
                  lock_args_method: ->(args) { [args.first, args.last, 'overseer-assessment'] },
                  on_conflict: :reject,
                  retry: 1

  def perform(task_id, _output_path, docker_image_name_tag, submission, assessment, timestamp, overseer_assessment_id)
    logger.info "Starting overseer job..."

    at(0)
    total(1)

    task = Task.find(task_id)
    task_definition = task.task_definition

    raise "PDF is still compiling" if task.processing_pdf? || !task.has_done_file?

    raise "Submission file not found: #{submission}" unless File.exist?(submission)

    active_overseer_steps = task_definition.overseer_steps.select(&:enabled)

    raise "Task definition has no enabled overseer steps #{task.unit.detailed_name} #{task_definition.abbreviation}" if active_overseer_steps.empty?

    oa = OverseerAssessment.find(overseer_assessment_id)
    oa.update!(
      total_steps: active_overseer_steps.size
    )

    work_dir_name = "#{task.id}-#{overseer_assessment_id}"

    work_dir = Rails.root.join("tmp", "overseer", work_dir_name)
    FileUtils.mkdir_p(work_dir)

    extract_student_submission_files(task, submission, work_dir, timestamp)
    extract_overseer_resource_files(assessment, work_dir)

    success_status = nil
    failure_status = nil

    comment = task.comments.find_by(commentable: oa)
    unless comment
      oa.add_assessment_comment("Tests in progress")
    end

    steps_attempted = 0
    steps_passed = 0

    assessment_pass = true

    overseer_image = task_definition.overseer_image ||
                     task.unit.overseer_image ||
                     OverseerImage.find_by(tag: docker_image_name_tag)
    ensure_docker_image_present(docker_image_name_tag, overseer_image)

    active_overseer_steps.each do |step|
      result = run_overseer_step(
        step: step,
        work_dir: work_dir,
        work_dir_name: work_dir_name,
        task_id: task_id,
        timestamp: timestamp,
        docker_image_name_tag: docker_image_name_tag,
        overseer_assessment_id: overseer_assessment_id
      )

      steps_attempted += 1

      if result.valid? && result.pass
        steps_passed += 1
        if step.halt_on_success && step.status_on_success_id
          success_status = TaskStatus.find(step.status_on_success_id)
          break
        end
      elsif step.halt_on_failure
        failure_status = TaskStatus.find(step.status_on_failure_id) if step.status_on_failure_id
        assessment_pass = false
        break
      end
    end

    oa.update_assessment_comment("Tests complete: #{steps_passed} / #{active_overseer_steps.count}")

    if steps_attempted == steps_passed && assessment_pass
      oa.update!(status: :passed)
      unless success_status.nil?
        # TODO: have an override status setting for the step? eg. if the task is overdue, let it remain overdue, otherwise use this task status
        task.update!(task_status: success_status)
        task.add_status_comment(task.project.tutor_for(task.task_definition), success_status)

        oa.update!(result_task_status: success_status.status_key.to_s)
      end
    else
      oa.update!(status: :failed)
      # preserve_status_on_failure = [TaskStatus.time_exceeded.id, TaskStatus.assess_in_portfolio.id].include?(task.task_status_id)

      unless failure_status.nil? # || preserve_status_on_failure
        # TODO: have an override status setting for the step? eg. if the task is overdue, let it remain overdue, otherwise use this task status
        task.update!(task_status: failure_status)
        task.add_status_comment(task.project.tutor_for(task.task_definition), failure_status)
        oa.update!(result_task_status: failure_status.status_key.to_s)
      end
      task.add_text_comment(
        task.project.tutor_for(task.task_definition),
        "**Automated comment**: Some tests did not pass for this submission. Please review the Overseer report, verify your output, and resubmit.",
        attention_audience: :student
      )
    end

    FileUtils.rm_rf(work_dir)

    logger.info "Completed overseer job"
  rescue StandardError => e
    logger.error e
    raise e
  end

  def ensure_docker_image_present(docker_image_name_tag, overseer_image)
    _, _, inspect_status = Open3.capture3('docker', 'image', 'inspect', docker_image_name_tag)
    return if inspect_status.success?

    raise "Docker image #{docker_image_name_tag} is not configured" if overseer_image.nil?

    overseer_image.pull_from_docker
    return if overseer_image.success?

    raise "Unable to pull Docker image #{docker_image_name_tag}: #{overseer_image.pulled_image_text}"
  end

  def run_overseer_step(step:, work_dir:, work_dir_name:, task_id:, timestamp:, docker_image_name_tag:, overseer_assessment_id:)
    script_contents = step.run_command
    raise "Execution script is empty" if script_contents.blank?

    decoded =
      if script_contents.start_with?("b64:")
        begin
          Base64.urlsafe_decode64(script_contents.delete_prefix("b64:"))
        rescue ArgumentError
          raise "Invalid overseer script content"
        end
      else
        script_contents
      end

    # Create script
    run_sh_path = File.join(work_dir, 'run.sh')
    File.write(run_sh_path, decoded)

    # Ensure script is executable
    system("chmod +x #{run_sh_path}")

    mount = Doubtfire::Application.config.overseer_workdir_volume_mount
    volume_mount =
      if mount.nil?
        # Fallback for development only — mounts the entire overseer container volume,
        # allowing all task work directories to be accessible. This should never be
        # used in production, as it breaks isolation between tasks.
        "--volumes-from #{Doubtfire::Application.config.overseer_fallback_volume_container}"
      else
        # Absolute path on the hosting server to the shared mount
        "-v #{mount}/#{work_dir_name}:/overseer/work-dir/#{work_dir_name}"
      end

    # Max runtime (seconds) before force-killing the step (exit status 124)
    timeout = step.timeout
    timeout = 30 if timeout.nil? || timeout.negative?

    container_name = "overseer-#{task_id}-#{timestamp}"

    command = %(
      timeout #{timeout} docker run --rm -i \
      --pull never \
      --cpus 1 \
      --network none \
      #{volume_mount} \
      --name #{container_name} \
      #{docker_image_name_tag} \
      bash -c "cd /overseer/work-dir/#{work_dir_name} && timeout #{timeout} ./run.sh"
    )

    stdin_input_file = nil
    expected_output_file = nil

    # Retrieve names of input/output files
    if step.step_type == 'output_diff'
      stdin_input_file = step.stdin_input_file.present? ? File.join(work_dir, step.stdin_input_file) : nil
      expected_output_file = step.expected_output_file.present? ? File.join(work_dir, step.expected_output_file) : nil
    end

    output = ""
    status = nil
    stdin_contents = nil

    # Execute script and capture output
    Open3.popen2e(command) do |stdin, stdout_err, wait_thr|
      # If input file exists, pass it as standard input
      if stdin_input_file && File.exist?(stdin_input_file)
        File.open(stdin_input_file, 'rb') { |f| IO.copy_stream(f, stdin) }
        stdin_contents = File.read(stdin_input_file)
        stdin.close
      end

      stdout_err.each { |line| output << line }
      status = wait_thr.value
    end

    output = output.chomp
    pass = status.exitstatus == 0

    expected_output_contents = nil

    # If step type is comparing output, retrieve expected output file contents
    if step.step_type == 'output_diff'
      expected_output_contents =
        if expected_output_file && File.exist?(expected_output_file)
          File.read(expected_output_file)
        else
          ''
        end
      matches_output = if step.partial_output_diff
                         output.include?(expected_output_contents)
                       else
                         output == expected_output_contents
                       end

      pass = false unless matches_output
    end

    feedback_message =
      if step.feedback_message.blank?
        if step.step_type == 'output_diff'
          "Your output did not match the expected result."
        else
          "This test did not complete successfully. Check the output for any errors."
        end
      else
        step.feedback_message
      end

    output_truncated = output&.first(20_000)

    OverseerStepResult.create!(
      overseer_assessment_id: overseer_assessment_id,
      overseer_step: step,
      exit_status: status.exitstatus,
      pass: pass,
      feedback_message: feedback_message,
      stdout: output_truncated,
      stdin: stdin_contents,
      expected_output: expected_output_contents,
      stdout_sha256: Digest::SHA256.hexdigest(output),
      stdin_sha256: stdin_contents && Digest::SHA256.hexdigest(stdin_contents),
      expected_output_sha256: expected_output_contents && Digest::SHA256.hexdigest(expected_output_contents)
    )
  end

  def extract_student_submission_files(task, submission, work_dir, timestamp)
    # Submission files are stored directly under their timestamp in the task archive.
    Zip::File.open(submission) do |history_zip|
      prefix = "#{FileHelper.sanitized_path(timestamp.to_s)}/"
      entries = history_zip.entries.reject(&:name_is_directory?).select { |entry| entry.name.start_with?(prefix) }
      raise "Submission history entries not found for timestamp: #{timestamp}" if entries.empty?

      extract_submission_entries(task, entries, work_dir, prefix)
    end
  end

  def extract_submission_entries(task, entries, work_dir, prefix)
    # Extract submission files, removing any parent folders.
    entries.each do |entry|
      parts = entry.name.delete_prefix(prefix).split('/')
      next unless parts.first == task.id.to_s && parts.length >= 2

      file_name = parts.second
      index = file_name.to_i

      file = task.upload_requirements[index]
      final_name = file['name']

      dest_path = File.join(work_dir, final_name)
      FileUtils.mkdir_p(File.dirname(dest_path))
      entry.extract(dest_path) { true }
    end
  end

  def extract_overseer_resource_files(assessment, work_dir)
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
  end
end
