require 'test_helper'

class FeedbackWarningNotificationJobTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  class FakeRedis
    attr_reader :store

    def initialize
      @store = {}
    end

    def get(key)
      store[key]
    end

    def set(key, value, **options)
      return if options[:nx] && store.key?(key)

      store[key] = value
      'OK'
    end
  end

  def setup
    @now = Time.zone.local(2026, 9, 7, 9)
    teaching_period = FactoryBot.create(
      :teaching_period,
      start_date: @now - 2.weeks,
      end_date: @now + 2.months,
      active_until: @now + 3.months
    )
    @unit = FactoryBot.create(
      :unit,
      teaching_period: teaching_period,
      task_count: 1,
      feedback_warning_threshold_days: 5
    )
    definition = @unit.task_definitions.first
    # The factory grades the definition and its projects at random, so pin the
    # definition below every project rather than hoping one was generated above
    # it. Only the fully enrolled students hold a tutorial.
    definition.update!(target_grade: 0)
    @project = @unit.active_projects.find { |project| project.tutorial_for(definition).present? }
    @task = @project.task_for_task_definition(definition)
    @tutor = FactoryBot.create(:user, :tutor)
    @tutor_role = @unit.employ_staff(@tutor, Role.tutor)
    @project.tutorial_for(@task.task_definition).update!(unit_role: @tutor_role)
    @task.update!(
      task_status: TaskStatus.ready_for_feedback,
      submission_date: @now - 5.days
    )
  end

  def test_creates_one_warning_for_the_assigned_tutor_at_the_threshold
    2.times { Notification.refresh_feedback_warning_notifications!(now: @now) }

    notifications = Notification.where(task: @task, kind: 'feedback_warning')
    assert_equal 1, notifications.count
    assert_equal @tutor, notifications.first.recipient
  end

  def test_does_not_warn_before_the_threshold
    @task.update!(submission_date: @now - 5.days + 1.minute)

    Notification.refresh_feedback_warning_notifications!(now: @now)

    assert_not Notification.exists?(task: @task, kind: 'feedback_warning')
  end

  def test_teaching_breaks_pause_the_warning_clock
    @unit.teaching_period.add_break(@now - 4.days, 7)

    Notification.refresh_feedback_warning_notifications!(now: @now)

    assert_not Notification.exists?(task: @task, kind: 'feedback_warning')
  end

  def test_falls_back_to_the_main_convenor_when_no_tutor_is_assigned
    @project.tutorial_for(@task.task_definition).update!(unit_role: nil)

    Notification.refresh_feedback_warning_notifications!(now: @now)

    assert_equal @unit.main_convenor_user,
                 Notification.find_by!(task: @task, kind: 'feedback_warning').recipient
  end

  def test_resolves_a_warning_when_the_task_no_longer_needs_feedback
    Notification.refresh_feedback_warning_notifications!(now: @now)
    notification = Notification.find_by!(task: @task, kind: 'feedback_warning')
    @task.update!(task_status: TaskStatus.complete)

    Notification.refresh_feedback_warning_notifications!(now: @now + 1.hour)

    assert_not_nil notification.reload.read_at
    assert_not_nil notification.email_processed_at
  end

  def test_reassignment_resolves_the_old_warning_and_notifies_the_new_tutor
    Notification.refresh_feedback_warning_notifications!(now: @now)
    original = Notification.find_by!(task: @task, kind: 'feedback_warning')
    replacement = FactoryBot.create(:user, :tutor)
    replacement_role = @unit.employ_staff(replacement, Role.tutor)
    @project.tutorial_for(@task.task_definition).update!(unit_role: replacement_role)

    Notification.refresh_feedback_warning_notifications!(now: @now + 1.hour)

    assert_not_nil original.reload.read_at
    assert Notification.exists?(task: @task, kind: 'feedback_warning', recipient: replacement, read_at: nil)
  end

  def test_withdrawal_threshold_and_unit_state_changes_resolve_warnings
    assert_resolves_warning { @project.update!(enrolled: false) }
    reset_warning(submission_date: @now - 6.days)
    assert_resolves_warning { @unit.update!(feedback_warning_threshold_days: 7) }
    @unit.update!(feedback_warning_threshold_days: 5)
    reset_warning(submission_date: @now - 8.days)
    assert_resolves_warning { @unit.update!(active: false) }
  end

  def test_a_resubmission_can_raise_another_warning
    Notification.refresh_feedback_warning_notifications!(now: @now)
    first = Notification.find_by!(task: @task, kind: 'feedback_warning')
    @task.update!(task_status: TaskStatus.complete)
    Notification.refresh_feedback_warning_notifications!(now: @now + 1.hour)
    @task.update!(
      task_status: TaskStatus.ready_for_feedback,
      submission_date: @now + 2.days
    )

    Notification.refresh_feedback_warning_notifications!(now: @now + 7.days)

    warnings = Notification.where(task: @task, kind: 'feedback_warning').order(:id)
    assert_equal 2, warnings.count
    assert_equal first, warnings.first
    assert_nil warnings.last.read_at
  end

  def test_groups_pending_tasks_then_starts_a_new_group_after_email_delivery
    create_warning_task(submitted_at: @now - 6.days)
    Notification.refresh_feedback_warning_notifications!(now: @now)
    settings = NotificationSetting.for(@tutor)

    assert_emails 1 do
      SendNotificationDigestJob.new.perform(settings.id)
    end

    delivered = Notification.where(recipient: @tutor, kind: 'feedback_warning')
    assert_equal 2, delivered.count
    assert(delivered.all? { |notification| notification.email_sent_at.present? })
    assert_includes ActionMailer::Base.deliveries.last.text_part.body.to_s, '2 tasks that require feedback'
    assert_includes ActionMailer::Base.deliveries.last.text_part.body.to_s,
                    "/units/#{@unit.id}/tasks/inbox"

    create_warning_task(submitted_at: @now - 7.days)
    Notification.refresh_feedback_warning_notifications!(now: @now + 1.hour)
    groups = NotificationGroupBuilder.new(
      Notification.where(recipient: @tutor, kind: 'feedback_warning').unread
    ).groups

    assert_equal [1, 2], groups.map { |group| group[:counts]['feedback_warning'] }.sort
    pending = groups.find { |group| group[:counts]['feedback_warning'] == 1 }
    assert_equal({ type: 'unit_inbox', unit_id: @unit.id }, pending[:destination])
    assert_equal 'warning', pending[:severity]
  end

  def test_disabled_channels_prevent_creation
    settings = NotificationSetting.for(@tutor)
    settings.update!(channels: settings.channels.merge('feedback_warning' => []))

    Notification.refresh_feedback_warning_notifications!(now: @now)

    assert_not Notification.exists?(task: @task, kind: 'feedback_warning')
  end

  def test_first_job_run_only_sets_the_rollout_boundary
    Notification.refresh_feedback_warning_notifications!(now: @now)
    existing = Notification.find_by!(task: @task, kind: 'feedback_warning')
    redis = FakeRedis.new

    with_sidekiq_redis(redis) do
      travel_to(@now) { NotifyFeedbackWarningsJob.new.perform }
      travel_to(@now + 1.hour) { NotifyFeedbackWarningsJob.new.perform }
    end

    assert_nil existing.reload.read_at
    assert_nil existing.email_processed_at
    assert_equal 1, Notification.where(task: @task, kind: 'feedback_warning').count
    assert redis.store.key?(NotifyFeedbackWarningsJob::ROLLOUT_KEY)
  end

  def test_job_notifies_an_existing_submission_only_when_it_crosses_after_rollout
    @task.update!(submission_date: @now - 4.days)
    redis = FakeRedis.new

    with_sidekiq_redis(redis) do
      travel_to(@now) { NotifyFeedbackWarningsJob.new.perform }
      assert_not Notification.exists?(task: @task, kind: 'feedback_warning')

      travel_to(@now + 1.day) { NotifyFeedbackWarningsJob.new.perform }
    end

    assert Notification.exists?(task: @task, kind: 'feedback_warning', recipient: @tutor)
  end

  private

  def create_warning_task(submitted_at:)
    definition = FactoryBot.create(
      :task_definition,
      unit: @unit,
      tutorial_stream: @task.task_definition.tutorial_stream,
      target_grade: @task.task_definition.target_grade
    )
    FactoryBot.create(
      :task,
      project: @project,
      task_definition: definition,
      task_status: TaskStatus.ready_for_feedback,
      submission_date: submitted_at
    )
  end

  def reset_warning(submission_date:)
    @project.update!(enrolled: true)
    @task.update!(task_status: TaskStatus.ready_for_feedback, submission_date: submission_date)
    Notification.refresh_feedback_warning_notifications!(now: @now)
  end

  def assert_resolves_warning
    Notification.refresh_feedback_warning_notifications!(now: @now)
    notification = Notification.where(task: @task, kind: 'feedback_warning').unread.first!
    yield
    Notification.refresh_feedback_warning_notifications!(now: @now + 1.hour)
    assert_not_nil notification.reload.read_at
  end

  def with_sidekiq_redis(redis)
    original = Sidekiq.method(:redis)
    Sidekiq.define_singleton_method(:redis) { |&redis_block| redis_block.call(redis) }
    yield
  ensure
    Sidekiq.define_singleton_method(:redis, original)
  end
end
