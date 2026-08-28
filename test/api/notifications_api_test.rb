require 'test_helper'

class NotificationsApiTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper

  def app
    Rails.application
  end

  def setup
    super
    @unit = FactoryBot.create(:unit, task_count: 1)
    @project = @unit.active_projects.first
    @task = @project.task_for_task_definition(@unit.task_definitions.first)
    @student = @project.student
    @tutor = @project.tutor_for(@task.task_definition)
    @task.add_text_comment(@tutor, 'New feedback')
    add_auth_header_for(user: @student)
  end

  def test_get_returns_only_current_users_grouped_notifications
    other_user = FactoryBot.create(:user)
    FactoryBot.create(:notification, recipient: other_user, unit: @unit)

    get '/api/notifications'

    assert_equal 200, last_response.status
    assert_equal 1, last_response_body['groups'].count
    assert_equal @task.id, last_response_body.dig('groups', 0, 'task', 'id')
    assert_equal 1, last_response_body['unread_count']
  end

  def test_unread_count_counts_a_task_group_instead_of_each_event
    @task.add_text_comment(@tutor, 'More feedback')
    @task.add_status_comment(@tutor, TaskStatus.fix_and_resubmit)

    get '/api/notifications/unread_count'

    assert_equal 200, last_response.status
    assert_equal 1, last_response_body['count']
  end

  def test_portfolio_notifications_are_grouped_by_project
    @student.received_notifications.destroy_all
    Notification.create_for_portfolio(@project, success: true)

    get '/api/notifications'

    assert_equal 200, last_response.status
    assert_equal 1, last_response_body['unread_count']
    assert_equal @project.id, last_response_body.dig('groups', 0, 'project_id')
    assert_equal({ 'portfolio_ready' => 1 }, last_response_body.dig('groups', 0, 'counts'))
  end

  def test_communication_emails_are_returned_individually_with_their_full_content
    @student.received_notifications.destroy_all
    2.times do |index|
      Notification.create_for_communication_email(
        recipient: @student,
        unit: @unit,
        project: @project,
        actor: @tutor,
        subject: "Update #{index}",
        body: "Full email body #{index}",
        deduplication_key: "communication-email:api-test:#{index}"
      )
    end

    get '/api/notifications', state: 'unread'

    assert_equal 200, last_response.status
    assert_equal 2, last_response_body['unread_count']
    assert_equal 2, last_response_body['groups'].count
    assert_equal ['Update 0', 'Update 1'], last_response_body['groups'].pluck('message_subject').sort
    assert_equal ['Full email body 0', 'Full email body 1'], last_response_body['groups'].pluck('message_body').sort
  end

  def test_get_filters_groups_by_category_and_search
    get '/api/notifications',
        state: 'unread',
        kinds: ['new_task_comment'],
        query: @unit.code

    assert_equal 200, last_response.status
    assert_equal 1, last_response_body['groups'].count
    assert_equal({ 'new_task_comment' => 1 }, last_response_body.dig('groups', 0, 'counts'))
  end

  def test_mark_read_cannot_update_another_users_notification
    own_notification = Notification.find_by!(recipient: @student)
    other_notification = FactoryBot.create(:notification, unit: @unit)

    put_json '/api/notifications/read',
             notification_ids: [own_notification.id, other_notification.id]

    assert_equal 200, last_response.status
    assert_not_nil own_notification.reload.read_at
    assert_nil other_notification.reload.read_at
  end

  def test_mark_all_read_can_be_scoped_to_a_unit
    own_notification = Notification.find_by!(recipient: @student)
    other_unit = FactoryBot.create(:unit, with_students: false, task_count: 0)
    other_notification = FactoryBot.create(:notification, recipient: @student, unit: other_unit)

    put_json '/api/notifications/read_all', unit_id: @unit.id

    assert_equal 200, last_response.status
    assert_not_nil own_notification.reload.read_at
    assert_nil other_notification.reload.read_at
  end

  def test_a_kind_switched_off_in_app_is_hidden_but_still_emailed
    settings = NotificationSetting.for(@student)
    settings.update!(channels: settings.channels.merge('new_task_comment' => ['email']))

    get '/api/notifications'

    assert_equal 200, last_response.status
    assert_empty last_response_body['groups']
    assert_equal 0, last_response_body['unread_count']

    # The event is still on the ledger, waiting for the digest to pick it up.
    assert_equal 1, @student.received_notifications.email_pending.where(kind: 'new_task_comment').count
  end

  def test_settings_start_from_the_defaults
    get '/api/notification_settings'

    assert_equal 200, last_response.status
    assert_equal 'weekly', last_response_body['digest_frequency']
    assert_equal 4, last_response_body['digest_interval_hours']
    assert_equal '08:00', last_response_body['digest_start_time']
    assert_equal @project.campus.timezone, last_response_body['digest_timezone']
    assert_equal %w[in_app email], last_response_body.dig('channels', 'new_task_comment')
    assert_empty last_response_body['units']
  end

  def test_updating_settings_stores_the_schedule_and_the_units_that_differ
    put_json '/api/notification_settings',
             channels: { new_task_comment: ['in_app'] },
             digest_frequency: 'daily',
             digest_interval_hours: 6,
             digest_start_time: '09:00',
             digest_time: '10:30',
             digest_weekday: 1,
             weekly_summary: false,
             units: [{ unit_id: @unit.id, muted: true }]

    assert_equal 200, last_response.status
    assert_equal 'daily', last_response_body['digest_frequency']
    assert_equal 6, last_response_body['digest_interval_hours']
    assert_equal '09:00', last_response_body['digest_start_time']
    assert_equal @project.campus.timezone, last_response_body['digest_timezone']
    assert_equal ['in_app'], last_response_body.dig('channels', 'new_task_comment')
    assert_equal [{ 'unit_id' => @unit.id, 'muted' => true, 'channels' => nil }], last_response_body['units']
  end

  def test_updating_settings_drops_units_that_no_longer_differ
    NotificationUnitOverride.create!(user: @student, unit: @unit, muted: true)

    put_json '/api/notification_settings',
             channels: { new_task_comment: ['in_app'] },
             digest_frequency: 'daily',
             digest_time: '10:30',
             digest_weekday: 1,
             weekly_summary: true,
             units: []

    assert_equal 200, last_response.status
    assert_empty @student.notification_unit_overrides.reload
  end

  def test_updating_settings_ignores_units_the_user_cannot_access
    inaccessible = FactoryBot.create(:unit, with_students: false, task_count: 0)

    put_json '/api/notification_settings',
             channels: { new_task_comment: ['in_app'] },
             digest_frequency: 'daily',
             digest_time: '10:30',
             digest_weekday: 1,
             weekly_summary: true,
             units: [{ unit_id: inaccessible.id, muted: true }]

    assert_equal 200, last_response.status
    assert_empty last_response_body['units']
  end

  def test_updating_settings_rejects_an_unknown_frequency
    put_json '/api/notification_settings', digest_frequency: 'fortnightly'

    assert_equal 400, last_response.status
  end

  def test_updating_settings_rejects_an_unknown_digest_interval
    put_json '/api/notification_settings', digest_interval_hours: 5

    assert_equal 400, last_response.status
  end

  def test_updating_settings_leaves_out_what_was_not_sent
    put_json '/api/notification_settings', digest_frequency: 'daily'
    NotificationUnitOverride.create!(user: @student, unit: @unit, muted: true)

    # The client only sends what changed, so an absent key must not clear anything.
    put_json '/api/notification_settings', digest_time: '06:00'

    assert_equal 200, last_response.status
    assert_equal 'daily', last_response_body['digest_frequency']
    assert_equal '06:00', last_response_body['digest_time']
    assert_equal 1, @student.notification_unit_overrides.reload.count
  end
end
