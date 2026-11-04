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
end
