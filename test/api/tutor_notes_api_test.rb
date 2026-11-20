require 'test_helper'

class TutorNotesApiTest < ActiveSupport::TestCase
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
    @convenor = @unit.main_convenor_user

    @tutor = FactoryBot.create(:user, :tutor)
    @unit.employ_staff(@tutor, Role.tutor)
    @tutor_role = @unit.unit_role_for(@tutor)
  end

  def test_a_note_written_about_you_asks_you_to_mark_it_read
    about_me = @tutor_role.add_tutor_note(@convenor, 'Please review this feedback', @task.id)
    add_auth_header_for(user: @tutor)

    get "/api/unit_roles/#{@tutor_role.id}/tutor_notes"

    assert_equal 200, last_response.status
    note = last_response_body.find { |result| result['id'] == about_me.id }
    assert note['requires_current_user_read']
  end

  def test_your_own_note_never_asks_you_to_mark_it_read
    mine = @tutor_role.add_tutor_note(@tutor, 'A note on my own moderation notes', @task.id)
    add_auth_header_for(user: @tutor)

    get "/api/unit_roles/#{@tutor_role.id}/tutor_notes"

    assert_equal 200, last_response.status
    note = last_response_body.find { |result| result['id'] == mine.id }
    assert_not note['requires_current_user_read']
  end
end
