require 'test_helper'

class UnitsTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper

  def app
    Rails.application
  end

  setup do
    @student = FactoryBot.create(:user, :student)
  end

  teardown do
    @student.destroy
  end

  test 'Setting enabled creates or destroys webcal' do
    # Enable webcal
    put_json '/api/webcal', with_auth_token({ webcal: { enabled: true } }, @student)

    # Ensure enabled
    assert_not_nil Webcal.find_by(user: @student)

    get with_auth_token('/api/webcal', @student)
    assert_equal 200, last_response.status
    assert last_response_body['enabled']

    # Disable webcal
    put_json '/api/webcal', with_auth_token({ webcal: { enabled: false } }, @student)

    # Ensure disabled
    assert_nil Webcal.find_by(user: @student)

    get with_auth_token('/api/webcal', @student)
    assert_equal 200, last_response.status
    assert_not last_response_body['enabled']
  end

  test 'Enabled with sensible defaults' do

    # Ensure webcal disabled
    put_json '/api/webcal', with_auth_token({ webcal: { enabled: false } }, @student)

    # Enable webcal
    put_json '/api/webcal', with_auth_token({ webcal: { enabled: true } }, @student)

    # Ensure sensible defaults in the database
    webcal = @student.webcal
    assert_equal [], webcal.webcal_unit_exclusions
    assert_not webcal.include_start_dates
    assert_nil webcal.reminder_time
    assert_nil webcal.reminder_unit
  end

  test 'should_change_guid changes guid' do
    # Enable webcal, get GUID
    put_json '/api/webcal', with_auth_token({ webcal: { enabled: true } }, @student)
    prev_guid = last_response_body['guid']

    # Request GUID change
    put_json '/api/webcal', with_auth_token({ webcal: { should_change_guid: true } }, @student)
    current_guid = last_response_body['guid']

    # Ensure GUID changed
    assert_not_equal prev_guid, current_guid

    get with_auth_token('/api/webcal', @student)
    assert_equal current_guid, last_response_body['guid']
  end

  test 'Ical endpoint is public and serves webcal with corect content type' do
    # Enable webcal, get GUID
    put_json '/api/webcal', with_auth_token({ webcal: { enabled: true } }, @student)
    guid = last_response_body['guid']

    # Retrieve ical _without auth_
    get "/api/webcal/#{guid}"

    # Ensure correct content type
    assert_equal 200, last_response.status
    assert_equal 'text/calendar', last_response['Content-Type']
  end

  test 'Reminder must be specified with both time & unit' do
    # Enable webcal
    put_json '/api/webcal', with_auth_token({ webcal: { enabled: true } }, @student)

    # Specify only time
    put_json '/api/webcal', with_auth_token({ webcal: { reminder: { time: 5 } } }, @student)
    assert_equal 400, last_response.status

    # Specify only unit
    put_json '/api/webcal', with_auth_token({ webcal: { reminder: { unit: 'D' } } }, @student)
    assert_equal 400, last_response.status

    # Specify both time & unit
    Webcal.valid_time_units.each_with_index { |u, i|
      t = i + 1

      put_json '/api/webcal', with_auth_token({ webcal: { reminder: { time: t, unit: u } } }, @student)
      assert_equal 200, last_response.status

      assert_not_nil last_response_body['reminder']
      assert_equal t, last_response_body['reminder']['time']
      assert_equal u, last_response_body['reminder']['unit']
    }
  end
end
