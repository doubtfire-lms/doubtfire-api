require 'test_helper'
require 'rake'
require 'tmpdir'

class MaintenanceStalePlagiarismMarkerTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?('maintenance:alert_stale_plagiarism_marker')

    @original_student_work_dir = Doubtfire::Application.config.student_work_dir
    @original_email_errors_to = Doubtfire::Application.config.email_errors_to
    @student_work_dir = Dir.mktmpdir('stale-plagiarism-marker')
    Doubtfire::Application.config.student_work_dir = @student_work_dir
    Doubtfire::Application.config.email_errors_to = 'ops@example.com'
    @task = Rake::Task['maintenance:alert_stale_plagiarism_marker']
  end

  teardown do
    @task.reenable
    Doubtfire::Application.config.student_work_dir = @original_student_work_dir
    Doubtfire::Application.config.email_errors_to = @original_email_errors_to
    FileUtils.remove_entry(@student_work_dir)
  end

  def test_alerts_when_marker_is_older_than_seven_days
    marker_path = File.join(@student_work_dir, 'rake.plagiarism.running')
    File.write(marker_path, '')
    stale_time = 8.days.ago.to_time
    File.utime(stale_time, stale_time, marker_path)

    assert_emails 1 do
      @task.reenable
      @task.invoke
    end
    assert_includes ActionMailer::Base.deliveries.last.subject, 'Plagiarism checks blocked'
  end

  def test_does_not_alert_without_a_stale_marker
    assert_emails 0 do
      @task.reenable
      @task.invoke
    end

    marker_path = File.join(@student_work_dir, 'rake.plagiarism.running')
    File.write(marker_path, '')
    recent_time = 6.days.ago.to_time
    File.utime(recent_time, recent_time, marker_path)

    assert_emails 0 do
      @task.reenable
      @task.invoke
    end
  end
end
