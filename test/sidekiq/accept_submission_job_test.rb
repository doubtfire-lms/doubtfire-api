require 'test_helper'
require 'minitest/mock'

class AcceptSubmissionJobTest < ActiveSupport::TestCase
  def test_failed_pdf_conversion_does_not_queue_submission_history
    task = FactoryBot.create(:task)
    task.task_definition.update!(
      upload_requirements: [
        { 'key' => 'file0', 'name' => 'main.rb', 'type' => 'code', 'submission_history' => true }
      ]
    )
    user = task.project.student
    user.update!(receive_task_notifications: false)

    perform_job = lambda do
      Task.stub(:find, task) do
        User.stub(:find, user) do
          task.stub(:convert_submission_to_pdf, false) do
            ErrorLogMailer.stub(:error_message, nil) do
              job = AcceptSubmissionJob.new
              job.stub(:ensure_submission_files_visible!, nil) do
                job.perform(task.id, user.id, false, false)
              end
            end
          end
        end
      end
    end

    if defined?(Sentry)
      Sentry.stub(:capture_exception, nil) { perform_job.call }
    else
      perform_job.call
    end

    assert_empty CreateSubmissionHistoryJob.jobs
    assert_not SubmissionHistory.pending?(task)
  end

  def test_missing_submission_folder_does_not_process_previous_archive
    task = FactoryBot.create(:task)
    user = task.project.student
    job = AcceptSubmissionJob.new

    Task.stub(:find, task) do
      User.stub(:find, user) do
        Dir.stub(:children, ->(_path) { raise Errno::ENOENT }) do
          task.stub(:convert_submission_to_pdf, ->(**) { flunk 'Processed the previous archive' }) do
            assert_raises(AcceptSubmissionJob::SubmissionFilesNotVisible) do
              job.perform(task.id, user.id, false, false)
            end
          end
        end
      end
    end

    assert_empty CreateSubmissionHistoryJob.jobs
  end

  def test_retries_when_some_uploaded_files_are_not_visible
    task = FactoryBot.create(:task)
    task.task_definition.update!(
      upload_requirements: [
        { 'key' => 'file0', 'name' => 'main.rb', 'type' => 'code', 'submission_history' => true },
        { 'key' => 'file1', 'name' => 'report.pdf', 'type' => 'document' }
      ]
    )

    Dir.stub(:children, ['000-code.rb']) do
      File.stub(:file?, true) do
        error = assert_raises(AcceptSubmissionJob::SubmissionFilesNotVisible) do
          AcceptSubmissionJob.new.ensure_submission_files_visible!(task)
        end
        assert_match(%r{1/2}, error.message)
      end
    end
  end
end
