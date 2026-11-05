require 'test_helper'

class CompetenciesApiTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper

  def app
    Rails.application
  end

  def test_admin_can_build_a_framework_skill_and_level_catalog
    add_auth_header_for(user: FactoryBot.create(:user, :admin))

    post_json '/api/skill_frameworks', { skill_framework: { code: 'TESTSFIA', name: 'Test SFIA', version: '9-test' } }
    assert_equal 201, last_response.status, last_response_body
    framework_id = last_response_body.fetch('id')

    post_json "/api/skill_frameworks/#{framework_id}/skills", { skill: { code: 'PROG', name: 'Programming' } }
    assert_equal 201, last_response.status, last_response_body
    skill_id = last_response_body.fetch('id')

    post_json "/api/skills/#{skill_id}/levels", { skill_level: { name: 'Level 2', rank: 2, description: 'Applies programming skills' } }
    assert_equal 201, last_response.status, last_response_body
    assert_equal skill_id, last_response_body.fetch('skill_id')

    get '/api/skill_frameworks'
    framework = last_response_body.find { |item| item.fetch('id') == framework_id }
    ranks = framework.fetch('skills').first.fetch('levels').map { |level| level.fetch('rank') }
    assert_equal [2], ranks
  end

  def test_student_cannot_create_a_framework
    add_auth_header_for(user: FactoryBot.create(:user, :student))

    post_json '/api/skill_frameworks', { skill_framework: { code: 'UNAUTH', name: 'Unauthorised framework', version: '1' } }

    assert_equal 403, last_response.status
    assert_not SkillFramework.exists?(code: 'UNAUTH', version: '1')
  end

  def test_assigning_a_unit_definition_persists_after_reloading_the_offering
    unit = FactoryBot.create(:unit, with_students: false, task_count: 0, outcome_count: 0)
    legacy = UnitDefinition.create!(code: unit.code, name: unit.name, version: 'legacy')
    target = UnitDefinition.create!(code: unit.code, name: 'Programming foundations', version: '2027-S1')
    unit.update!(unit_definition: legacy)
    add_auth_header_for(user: FactoryBot.create(:user, :admin))

    put_json "/api/units/#{unit.id}/unit_definition", { unit_definition_id: target.id }

    assert_equal 200, last_response.status, last_response_body
    assert_equal target.id, last_response_body.fetch('unit_definition_id')
    assert_equal target.id, unit.reload.unit_definition_id

    get "/api/units/#{unit.id}/unit_definition"
    assert_equal target.id, last_response_body.fetch('unit_definition_id')
  end
end
