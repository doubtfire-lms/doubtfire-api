require 'test_helper'

class StatisticsApiTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper

  def app
    Rails.application
  end

  def test_get_statistics
    now = Time.current
    FactoryBot.create(:user, last_access_at: now - 2.minutes)
    FactoryBot.create(:user, last_access_at: now - 10.minutes)
    FactoryBot.create(:user, last_access_at: now - 45.minutes)
    FactoryBot.create(:user, last_access_at: now - 12.hours)
    FactoryBot.create(:user, last_access_at: now - 3.days)

    add_auth_header_for(user: FactoryBot.create(:user, :admin))
    get '/api/admin/statistics'

    assert_equal 200, last_response.status
    assert_equal User.where(last_access_at: (now - 5.minutes)..).count,
                 last_response_body.dig('activeUsers', 'fiveMinutes')
    assert_equal User.where(last_access_at: (now - 15.minutes)..).count,
                 last_response_body.dig('activeUsers', 'fifteenMinutes')
    assert_equal User.where(last_access_at: (now - 30.minutes)..).count,
                 last_response_body.dig('activeUsers', 'thirtyMinutes')
    assert_equal User.where(last_access_at: (now - 1.hour)..).count,
                 last_response_body.dig('activeUsers', 'oneHour')
    assert_equal User.where(last_access_at: (now - 24.hours)..).count,
                 last_response_body.dig('activeUsers', 'twentyFourHours')
    assert_equal User.where(last_access_at: (now - 7.days)..).count,
                 last_response_body.dig('activeUsers', 'sevenDays')
    assert_equal User.count, last_response_body['totalUsers']
  end

  def test_get_statistics_rejects_students
    add_auth_header_for(user: FactoryBot.create(:user, :student))
    get '/api/admin/statistics'

    assert_equal 403, last_response.status
  end
end
