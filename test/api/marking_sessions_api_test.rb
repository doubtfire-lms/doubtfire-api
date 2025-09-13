require 'test_helper'

class MarkingSessionsApiTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper

  def app
    Rails.application
  end

  def setup
    @unit = FactoryBot.create(:unit)
    @tutor = FactoryBot.create(:user, :tutor)
    @convenor = FactoryBot.create(:user, :convenor)
    @student = FactoryBot.create(:user, :student)
    @project = FactoryBot.create(:project, unit: @unit, user: @student)
    @task = FactoryBot.create(:task, project: @project)
    @unit.employ_staff(@tutor, Role.tutor)
    @unit.employ_staff(@convenor, Role.convenor)
    @marking_session = FactoryBot.create(:marking_session, 
                                        marker: @tutor, 
                                        unit: @unit,
                                        ip_address: '192.168.1.1',
                                        start_time: 1.hour.ago,
                                        duration_minutes: 60)
  end

  def test_get_specific_marking_session
    add_auth_header_for(user: @tutor)
    get "/api/marking_sessions/#{@marking_session.id}"
    assert_equal 200, last_response.status
    response_data = last_response_body
    assert_equal @marking_session.id, response_data['id']
    assert_equal @marking_session.marker_id, response_data['marker_id']
    assert_equal @marking_session.unit_id, response_data['unit_id']
  end

  def test_get_marking_sessions_by_tutor_id
    add_auth_header_for(user: @convenor)
    get "/api/marking_sessions/tutor/#{@tutor.id}"
    assert_equal 200, last_response.status
    response_data = last_response_body
    assert_equal 1, response_data.length
    assert_equal @marking_session.id, response_data[0]['id']
  end

  def test_get_tutor_analytics
    add_auth_header_for(user: @convenor)
    get "/api/marking_analytics/tutor/#{@tutor.id}"
    assert_equal 200, last_response.status
    response_data = last_response_body
    assert_equal 1, response_data['total_sessions']
    assert_equal 60, response_data['total_duration_minutes']
  end

  def test_unauthorized_access_to_other_tutor_session
    other_tutor = FactoryBot.create(:user, :tutor)
    add_auth_header_for(user: other_tutor)
    get "/api/marking_sessions/#{@marking_session.id}"
    assert_equal 403, last_response.status
  end
end
