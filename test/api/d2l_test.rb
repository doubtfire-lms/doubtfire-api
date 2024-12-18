require 'test_helper'

class D2lTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper
  include TestHelpers::TestFileHelper

  def app
    Rails.application
  end

  def test_can_add_d2l_details_to_unit
    unit = FactoryBot.create(:unit, with_students: false)

    add_auth_header_for(user: User.first)

    initial_count = D2lAssessmentMapping.count

    post "/api/units/#{unit.id}/d2l", { org_unit_id: '12345' }
    assert_equal 201, last_response.status, last_response.inspect

    assert_equal initial_count + 1, D2lAssessmentMapping.count
    assert_equal '12345', D2lAssessmentMapping.last.org_unit_id
    assert_equal unit.id, D2lAssessmentMapping.last.unit_id

    assert_equal unit.d2l_assessment_mapping, D2lAssessmentMapping.last
  end

  def test_ensure_only_one_d2l_mapping_per_unit
    unit = FactoryBot.create(:unit, with_students: false)
    d2l = D2lAssessmentMapping.create(unit: unit, org_unit_id: '12345')

    add_auth_header_for(user: User.first)

    initial_count = D2lAssessmentMapping.count

    post "/api/units/#{unit.id}/d2l", { org_unit_id: '54321' }
    assert_equal 400, last_response.status, last_response.inspect

    assert_equal initial_count, D2lAssessmentMapping.count
  end

  def test_convenor_needed_for_d2l_details
    unit = FactoryBot.create(:unit, with_students: false)
    user = FactoryBot.create(:user, :student)
    add_auth_header_for(user: user)

    post "/api/units/#{unit.id}/d2l", { org_unit_id: '12345' }
    assert_equal 403, last_response.status, last_response.inspect

    user = FactoryBot.create(:user, :tutor)
    add_auth_header_for(user: user)

    post "/api/units/#{unit.id}/d2l", { org_unit_id: '12345' }
    assert_equal 403, last_response.status, last_response.inspect

    user = FactoryBot.create(:user, :auditor)
    add_auth_header_for(user: user)

    post "/api/units/#{unit.id}/d2l", { org_unit_id: '12345' }
    assert_equal 403, last_response.status, last_response.inspect
  end

  def test_can_get_d2l_details_for_unit
    unit = FactoryBot.create(:unit, with_students: false)
    d2l = D2lAssessmentMapping.create(unit: unit, org_unit_id: '12345')

    add_auth_header_for(user: unit.main_convenor_user)

    get "/api/units/#{unit.id}/d2l"
    assert_equal 200, last_response.status, last_response.inspect

    assert_equal '12345', last_response_body['org_unit_id'], last_response_body
    assert_equal d2l.id, last_response_body['id']
  end

  def test_can_delete_d2l_details_for_unit
    unit = FactoryBot.create(:unit, with_students: false)
    d2l = D2lAssessmentMapping.create(unit: unit, org_unit_id: '12345')

    add_auth_header_for(user: unit.main_convenor_user)

    initial_count = D2lAssessmentMapping.count

    delete "/api/units/#{unit.id}/d2l"
    assert_equal 204, last_response.status, last_response.inspect

    assert_equal initial_count - 1, D2lAssessmentMapping.count

    unit.reload
    assert_nil unit.d2l_assessment_mapping
  end

  def test_can_update_d2l_details_for_unit
    unit = FactoryBot.create(:unit, with_students: false)
    d2l = D2lAssessmentMapping.create(unit: unit, org_unit_id: '12345')

    add_auth_header_for(user: unit.main_convenor_user)

    initial_count = D2lAssessmentMapping.count

    put "/api/units/#{unit.id}/d2l", { org_unit_id: '54321' }
    assert_equal 200, last_response.status, last_response.inspect

    assert_equal initial_count, D2lAssessmentMapping.count

    unit.reload
    assert_equal '54321', unit.d2l_assessment_mapping.org_unit_id
  end

  def test_can_login_to_d2l
    user = FactoryBot.create(:user, :convenor)
    add_auth_header_for(user: user)

    init_states = UserOauthState.count

    stub_request(:post, "https://auth.brightspace.com/core/connect/token")
      .to_return(
        status: 200,
        body: {
          'access_token' => "blah",
          'expires_at' => '1734493629',
          'refresh_token' => "blee.bloo",
          'scope' => "core:*:* enrollment:orgunit:read grades:*:*",
          'token_type' => "Bearer"
        }.to_json,
        headers: { 'Content-Type' => 'application/json;charset=UTF-8' }
      )

    get '/api/d2l/login_url'
    assert_equal 200, last_response.status, last_response.inspect

    # State is created for callback
    assert_equal init_states + 1, UserOauthState.count

    state = UserOauthState.last.state

    init_tokens = user.user_oauth_tokens.count

    # When the user logs in, they are redirected to the callback
    get '/api/d2l/callback', { code: '12345', state: state }
    assert_equal 200, last_response.status, last_response.inspect

    # The user should now have an oauth token
    user.reload
    assert_equal init_tokens + 1, user.user_oauth_tokens.count
  end

  def test_login_to_d2l_exposed_over_api
    unit = FactoryBot.create(:unit, with_students: false)

    add_auth_header_for(user: unit.main_convenor_user)

    post '/api/d2l/login_url'
    assert_equal 201, last_response.status, last_response.inspect

    assert_equal unit.main_convenor_user, UserOauthState.last.user
  end

  def test_old_state_and_oauth_tokens_are_destroyed
    user = FactoryBot.create(:user, :convenor)
    add_auth_header_for(user: user)

    state = UserOauthState.create(user: user, state: '12345')
    state.created_at = 31.minutes.ago
    state.save

    UserOauthState.destroy_old_states

    assert_nil UserOauthState.find_by(id: state.id)

    token = UserOauthToken.create(user: user, provider: :d2l, token: 'test', expires_at: 31.minutes.ago)

    UserOauthToken.destroy_old_tokens

    assert_nil UserOauthToken.find_by(id: token.id)
  end
end
