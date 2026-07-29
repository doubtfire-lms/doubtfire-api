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

  def test_get_filters_groups_by_category_and_search
    get '/api/notifications',
        state: 'unread',
        kinds: ['feedback_left'],
        query: @unit.code

    assert_equal 200, last_response.status
    assert_equal 1, last_response_body['groups'].count
    assert_equal({ 'feedback_left' => 1 }, last_response_body.dig('groups', 0, 'counts'))
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

  def test_updating_preferences_requires_unit_access
    inaccessible_unit = FactoryBot.create(:unit, with_students: false, task_count: 0)

    put_json "/api/notification_preferences/#{inaccessible_unit.id}",
             email_categories: ['feedback_left'],
             email_frequency: 'daily',
             email_time: '10:30',
             email_weekday: 1,
             timezone: 'UTC'

    assert_equal 403, last_response.status
  end

  def test_updating_preferences_validates_timezone
    put_json "/api/notification_preferences/#{@unit.id}",
             email_categories: ['feedback_left'],
             email_frequency: 'daily',
             email_time: '10:30',
             email_weekday: 1,
             timezone: 'Not/A-Timezone'

    assert_equal 400, last_response.status
  end
end
