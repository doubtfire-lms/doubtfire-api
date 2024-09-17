require 'test_helper'

class WebcalApiTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper

  def app
    Rails.application
  end

  setup do
    @student = FactoryBot.create(:user, :student, enrol_in: 2)
  end

  teardown do
    @student.projects.find_each { |project| project.destroy }
    @student.destroy
  end

  test 'Setting enabled creates or destroys webcal' do
    # Enable webcal
    add_auth_header_for user: @student
    put_json '/api/webcal', { webcal: { enabled: true } }

    # Ensure enabled
    assert_not_nil Webcal.find_by(user: @student)

    get '/api/webcal'
    assert_equal 200, last_response.status
    assert last_response_body['enabled']

    # Disable webcal
    put_json '/api/webcal', { webcal: { enabled: false } }

    # Ensure disabled
    assert_nil Webcal.find_by(user: @student)

    get '/api/webcal'
    assert_equal 200, last_response.status
    assert_not last_response_body['enabled']
  end

  test 'Enabled with sensible defaults' do
    add_auth_header_for user: @student

    # Ensure webcal disabled
    put_json '/api/webcal', { webcal: { enabled: false } }

    # Enable webcal
    add_auth_header_for user: @student
    put_json '/api/webcal', { webcal: { enabled: true } }
    assert_equal 200, last_response.status, last_response.inspect

    # Ensure sensible defaults in the database
    webcal = @student.webcal
    assert_equal [], webcal.webcal_unit_exclusions
    assert_not webcal.include_start_dates
    assert_nil webcal.reminder_time
    assert_nil webcal.reminder_unit
  end

  test 'should_change_guid changes guid' do
    add_auth_header_for user: @student
    # Enable webcal, get GUID
    put_json '/api/webcal', { webcal: { enabled: true } }
    prev_guid = last_response_body['guid']

    # Request GUID change
    add_auth_header_for user: @student
    put_json '/api/webcal', { webcal: { should_change_guid: true } }
    current_guid = last_response_body['guid']

    # Ensure GUID changed
    assert_not_equal prev_guid, current_guid
    get '/api/webcal'
    assert_equal current_guid, last_response_body['guid']
  end

  test 'Ical endpoint is public and serves webcal with corect content type' do
    add_auth_header_for user: @student
    # Enable webcal, get GUID
    put_json '/api/webcal', { webcal: { enabled: true } }
    guid = last_response_body['guid']

    # Retrieve ical _without auth_
    get "/api/webcal/#{guid}"

    # Ensure correct content type
    assert_equal 200, last_response.status
    assert_equal 'text/calendar', last_response['Content-Type']
  end

  test 'Reminder must be specified with both time & unit' do
    add_auth_header_for user: @student

    # Enable webcal
    put_json '/api/webcal', { webcal: { enabled: true } }

    # Specify only time
    put_json '/api/webcal', { webcal: { reminder: { time: 5 } } }
    assert 400, last_response.status

    # Specify only unit
    put_json '/api/webcal', { webcal: { reminder: { unit: 'D' } } }
    assert 400, last_response.status

    # Specify both time & unit
    Webcal.valid_time_units.each_with_index { |u, i|
      t = i + 1

      put_json '/api/webcal', { webcal: { reminder: { time: t, unit: u } } }
      assert 200, last_response.status

      assert_not_nil last_response_body['reminder']
      assert_equal t, last_response_body['reminder']['time']
      assert_equal u, last_response_body['reminder']['unit']
    }
  end

  test 'Can update unit exclusions' do
    add_auth_header_for user: @student

    # Enable webcal, get webcal ID
    put_json '/api/webcal', { webcal: { enabled: true } }
    id = last_response_body['id']

    # Exclude all units
    enrolled_units = @student.projects.joins(:unit).where(units: { active: true }).map(&:unit_id)
    put_json '/api/webcal', { webcal: { unit_exclusions: enrolled_units } }
    assert_equal enrolled_units.sort, last_response_body['unit_exclusions'].sort

    # Try exclude unit that student isn't enrolled in
    other_units = Unit.where.not(id: enrolled_units).map(&:id)

    put_json '/api/webcal', { webcal: { unit_exclusions: other_units } }
    assert_equal [], last_response_body['unit_exclusions']

    put_json '/api/webcal', { webcal: { unit_exclusions: enrolled_units + other_units } }
    assert_equal enrolled_units.sort, last_response_body['unit_exclusions'].sort

    # Include all units
    put_json '/api/webcal', { webcal: { unit_exclusions: [] } }
    assert_equal [], last_response_body['unit_exclusions']
  end
end
