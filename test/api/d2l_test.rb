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
    unit = FactoryBot.create(:unit)

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
    unit = FactoryBot.create(:unit)
    d2l = D2lAssessmentMapping.create(unit: unit, org_unit_id: '12345')

    add_auth_header_for(user: User.first)

    initial_count = D2lAssessmentMapping.count

    post "/api/units/#{unit.id}/d2l", { org_unit_id: '54321' }
    assert_equal 400, last_response.status, last_response.inspect

    assert_equal initial_count, D2lAssessmentMapping.count
  end

  def test_convenor_needed_for_d2l_details
    unit = FactoryBot.create(:unit)
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
    unit = FactoryBot.create(:unit)
    d2l = D2lAssessmentMapping.create(unit: unit, org_unit_id: '12345')

    add_auth_header_for(user: unit.main_convenor_user)

    get "/api/units/#{unit.id}/d2l"
    assert_equal 200, last_response.status, last_response.inspect

    assert_equal '12345', last_response_body['org_unit_id'], last_response_body
    assert_equal d2l.id, last_response_body['id']
  end

  def test_can_delete_d2l_details_for_unit
    unit = FactoryBot.create(:unit)
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
    unit = FactoryBot.create(:unit)
    d2l = D2lAssessmentMapping.create(unit: unit, org_unit_id: '12345')

    add_auth_header_for(user: unit.main_convenor_user)

    initial_count = D2lAssessmentMapping.count

    put "/api/units/#{unit.id}/d2l", { org_unit_id: '54321' }
    assert_equal 200, last_response.status, last_response.inspect

    assert_equal initial_count, D2lAssessmentMapping.count

    unit.reload
    assert_equal '54321', unit.d2l_assessment_mapping.org_unit_id
  end
end
