require 'test_helper'

class CommunicationRulesApiTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper

  def app
    Rails.application
  end

  def test_create_and_update_relative_activity_condition
    admin = FactoryBot.create(:user, :admin)
    unit = FactoryBot.create(:unit, with_students: false, task_count: 0, tutorials: 0, outcome_count: 0, staff_count: 0)
    communication_set = unit.communication_sets.create!(name: 'Activity', active: true)
    rule = communication_set.communication_rules.create!(name: 'Inactive students', operator: 'and', position: 0)
    add_auth_header_for(user: admin)

    post_json "/api/units/#{unit.id}/communication_rules/#{rule.id}/conditions",
              communication_condition: {
                type: 'LoginStatusCondition',
                operator: 'more_than',
                activity_days: 7
              }

    assert_equal 201, last_response.status
    condition_response = last_response_body
    assert_equal 'LoginStatusCondition', condition_response['type']
    assert_equal 'more_than', condition_response['operator']
    assert_equal 7, condition_response['activity_days']

    put_json "/api/units/#{unit.id}/communication_rules/#{rule.id}/conditions/#{condition_response['id']}",
             communication_condition: {
               type: 'UnitViewedStatusCondition',
               operator: 'within_last',
               activity_days: 3
             }

    assert_equal 200, last_response.status
    condition_response = last_response_body
    assert_equal 'UnitViewedStatusCondition', condition_response['type']
    assert_equal 'within_last', condition_response['operator']
    assert_equal 3, condition_response['activity_days']

    viewed_at = 1.day.ago.change(usec: 0)
    project = FactoryBot.create(:project, unit: unit, last_viewed_at: viewed_at)
    project.user.update!(last_sign_in_at: 2.days.ago.change(usec: 0))

    get "/api/units/#{unit.id}/communication_sets/#{communication_set.id}"

    assert_equal 200, last_response.status
    assert_equal 1, last_response_body['eligible_student_count']
    refute last_response_body.key?('previews')

    get "/api/units/#{unit.id}/communication_rules/#{rule.id}/preview"

    assert_equal 200, last_response.status
    assert_equal rule.id, last_response_body['rule_id']
    assert_equal 1, last_response_body['eligible_student_count']
    student = last_response_body['students'].first
    assert_equal project.id, student['project_id']
    assert_equal project.user.username, student['username']
    assert_equal false, student['has_portfolio']
    assert_equal viewed_at.iso8601(3), Time.zone.parse(student['last_viewed_at']).iso8601(3)
    assert_equal project.user.last_sign_in_at.iso8601(3), Time.zone.parse(student['last_sign_in_at']).iso8601(3)
  end

  def test_rule_preview_ignores_earlier_rules_in_the_set
    admin = FactoryBot.create(:user, :admin)
    unit = FactoryBot.create(:unit, with_students: false, task_count: 0, tutorials: 0, outcome_count: 0, staff_count: 0)
    communication_set = unit.communication_sets.create!(name: 'Spec con', active: true)
    first_rule = communication_set.communication_rules.create!(name: 'First', operator: 'and', position: 0)
    second_rule = communication_set.communication_rules.create!(name: 'Second', operator: 'and', position: 1)

    [first_rule, second_rule].each do |rule|
      rule.communication_conditions.create!(
        type: 'SpecConCondition',
        operator: 'greater_than_or_equal_to',
        spec_con_days: 3
      )
    end

    matching_project = FactoryBot.create(:project, unit: unit, spec_con_days: 4)
    FactoryBot.create(:project, unit: unit, spec_con_days: 1)
    add_auth_header_for(user: admin)

    # Both rules report the same student -- the second is no longer filtered by the first.
    [first_rule, second_rule].each do |rule|
      get "/api/units/#{unit.id}/communication_rules/#{rule.id}/preview"

      assert_equal 200, last_response.status
      assert_equal 2, last_response_body['eligible_student_count']
      assert_equal [matching_project.id], last_response_body['students'].map { |student| student['project_id'] }
    end
  end

  def test_create_and_update_portfolio_submitted_condition
    admin = FactoryBot.create(:user, :admin)
    unit = FactoryBot.create(:unit, with_students: false, task_count: 0, tutorials: 0, outcome_count: 0, staff_count: 0)
    communication_set = unit.communication_sets.create!(name: 'Portfolio', active: true)
    rule = communication_set.communication_rules.create!(name: 'Portfolio submitted', operator: 'and', position: 0)
    add_auth_header_for(user: admin)

    post_json "/api/units/#{unit.id}/communication_rules/#{rule.id}/conditions",
              communication_condition: {
                type: 'PortfolioSubmittedCondition',
                operator: 'equal_to',
                submitted_portfolio: true
              }

    assert_equal 201, last_response.status
    condition_response = last_response_body
    assert_equal true, condition_response['submitted_portfolio']

    put_json "/api/units/#{unit.id}/communication_rules/#{rule.id}/conditions/#{condition_response['id']}",
             communication_condition: {
               submitted_portfolio: false
             }

    assert_equal 200, last_response.status
    assert_equal false, last_response_body['submitted_portfolio']
    assert_equal false, rule.communication_conditions.find(condition_response['id']).submitted_portfolio
  end
end
