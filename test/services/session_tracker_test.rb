require "test_helper"

class SessionTrackerTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

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
      assert_equal @user, activity.marking_session.user
      assert_equal @unit, activity.marking_session.unit
    end
  end

  def test_reuses_existing_session_within_threshold
    session = MarkingSession.create!(
      user: @user,
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

  def test_uses_default_timezone_for_tutorial_without_campus
    unit = FactoryBot.create(:unit, with_students: false)
    unit_role = unit.staff.first
    activity_type = ActivityType.find_or_create_by!(abbreviation: "Feedback") do |type|
      type.name = "Feedback"
    end
    tutorial_stream = FactoryBot.create(:tutorial_stream, unit: unit, activity_type: activity_type)
    now = Time.zone.parse("2026-07-20 10:30:00")

    FactoryBot.create(
      :tutorial,
      unit: unit,
      unit_role: unit_role,
      tutorial_stream: tutorial_stream,
      campus: nil,
      meeting_day: now.strftime("%A"),
      meeting_time: "10:00"
    )

    travel_to(now) do
      session = SessionTracker.find_or_create_session(unit_role.user, unit, @ip_address)

      assert_predicate session, :during_tutorial?
    end
  end
end
