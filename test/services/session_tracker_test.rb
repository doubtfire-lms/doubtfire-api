require "test_helper"

class SessionTrackerTest < ActiveSupport::TestCase
  def setup
    @user = User.first
    @unit = Unit.first
    @project = Project.first
    @task = Task.first
    @ip_address = "192.168.1.1"
  end

  def test_creates_new_marking_session_and_session_activity
    assert_difference ["MarkingSession.count", "SessionActivity.count"], 1 do
      activity = SessionTracker.record_assessment_activity(
        action: "assessing",
        user: @user,
        project: @project,
        ip_address: @ip_address,
        task: @task
      )
      assert_equal "assessing", activity.action
      assert_equal @project.id, activity.project_id
      assert_equal @task.id, activity.task_id
      assert_equal @user, activity.marking_session.marker
      assert_equal @unit, activity.marking_session.unit
    end
  end

  def test_reuses_existing_session_within_threshold
    session = MarkingSession.create!(
      marker: @user,
      unit: @unit,
      ip_address: @ip_address,
      start_time: 10.minutes.ago
    )
    assert_no_difference "MarkingSession.count" do
      assert_difference "SessionActivity.count", 1 do
        activity = SessionTracker.record_assessment_activity(
          action: "assessing",
          user: @user,
          project: @project,
          ip_address: @ip_address,
          task: @task
        )
        assert_equal session.id, activity.marking_session_id
      end
    end
  end
end
