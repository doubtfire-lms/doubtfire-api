class SubmissionHistory < ApplicationRecord

  # TODO: so a submission history is going to be created after AcceptSubmissionJob completes successfully

  belongs_to :task, optional: false
  has_one :project, through: :task

  def self.create_for(task)
    task_definition = task.task_definition
    unit = task_definition.unit

    result = SubmissionHistory.create!(
      # task: task,
      # status: :pre_queued,
      submission_timestamp: Time.now.utc.to_i
    )

    # Create the submission folder and give access
    FileUtils.mkdir_p result.output_path
    result.grant_access_to_submission

    result.copy_latest_files_to_submission

    result
  end

  def has_submission_files?
    File.exist? submission_zip_file_name
  end

  def submission_zip_file_name
    # /submission_history/{UNIT}/{USERNAME}/done/submission.zip
    "#{output_path}/submission.zip"
  end

  def grant_access_to_submission
    # TODO: Use FACL instead in future.
    `chmod o+w #{output_path}`
  end

  def copy_latest_files_to_submission
    zip_file_path = submission_zip_file_name

    if task.has_new_files?
      puts "Copying new files to submission at: #{zip_file_path}"
      # Generate a zip file for this particular submission with timestamp value and put it here
      task.compress_new_to_done zip_file_path: zip_file_path, rm_task_dir: false, rename_files: true
    else
      puts "Copying done file to submission at: #{zip_file_path}"
      # TODO: here is where we might want to refactor submission history - enabling it separate from overseer
      # TODO: so if "submission history" is enabled for an upload req,
      task.copy_done_to zip_file_path
    end
  end

  # Path to where the submission and output are stored - includes the submission when it is to be processed
  def output_path
    FileHelper.task_submission_identifier_path_with_timestamp(:done, task, submission_timestamp)
  end

end
