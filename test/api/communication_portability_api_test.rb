require 'test_helper'

class CommunicationPortabilityApiTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper

  def app
    Rails.application
  end

  def test_export_then_import_into_a_unit_with_the_same_task
    admin = FactoryBot.create(:user, :admin)
    source_unit = unit_with_task('T1.1')
    target_unit = unit_with_task('T1.1')
    communication_set = set_with_task_rule(source_unit)
    add_auth_header_for(user: admin)

    get "/api/units/#{source_unit.id}/communication_sets/#{communication_set.id}/export"

    assert_equal 200, last_response.status
    document = last_response_body

    assert_equal 'ontrack.communication_set', document['format']

    post_json "/api/units/#{target_unit.id}/communication_sets/import", document: document

    assert_equal 201, last_response.status
    body = last_response_body

    assert_equal 0, body['report']['unresolved_count']
    assert_equal true, body['communication_set']['executable']
  end

  def test_importing_without_the_referenced_task_reports_it_and_blocks_execution
    admin = FactoryBot.create(:user, :admin)
    source_unit = unit_with_task('T1.1')
    target_unit = unit_with_task('Something else')
    communication_set = set_with_task_rule(source_unit)
    add_auth_header_for(user: admin)

    get "/api/units/#{source_unit.id}/communication_sets/#{communication_set.id}/export"
    document = last_response_body

    post_json "/api/units/#{target_unit.id}/communication_sets/import", document: document

    assert_equal 201, last_response.status
    body = last_response_body

    assert_equal 1, body['report']['unresolved_count']
    assert_equal 'T1.1', body['report']['unresolved'].first.dig('descriptor', 'abbreviation')
    assert_equal false, body['communication_set']['executable']

    imported_id = body['communication_set']['id']

    post_json "/api/units/#{target_unit.id}/communication_sets/#{imported_id}/execute", {}

    assert_equal 409, last_response.status
    assert_equal ['Chase T1.1'], last_response_body['unresolved_rules'].map { |rule| rule['name'] }
  end

  def test_a_dry_run_reports_without_creating_the_set
    admin = FactoryBot.create(:user, :admin)
    source_unit = unit_with_task('T1.1')
    target_unit = unit_with_task('Something else')
    communication_set = set_with_task_rule(source_unit)
    add_auth_header_for(user: admin)

    get "/api/units/#{source_unit.id}/communication_sets/#{communication_set.id}/export"
    document = last_response_body

    post_json "/api/units/#{target_unit.id}/communication_sets/import", document: document, dry_run: true

    assert_equal 201, last_response.status
    assert_equal 1, last_response_body['report']['unresolved_count']
    assert_nil last_response_body['communication_set']
    assert_equal 0, target_unit.communication_sets.count
  end

  def test_a_document_of_the_wrong_kind_is_rejected
    admin = FactoryBot.create(:user, :admin)
    source_unit = unit_with_task('T1.1')
    target_unit = unit_with_task('T1.1')
    communication_set = set_with_task_rule(source_unit)
    target_set = target_unit.communication_sets.create!(name: 'Existing', active: true)
    add_auth_header_for(user: admin)

    get "/api/units/#{source_unit.id}/communication_sets/#{communication_set.id}/export"
    document = last_response_body

    post_json "/api/units/#{target_unit.id}/communication_sets/#{target_set.id}/rules/import", document: document

    assert_equal 400, last_response.status
    assert_match 'ontrack.communication_rule', last_response_body['error']
  end

  def test_a_single_rule_can_be_imported_into_an_existing_set
    admin = FactoryBot.create(:user, :admin)
    source_unit = unit_with_task('T1.1')
    target_unit = unit_with_task('T1.1')
    rule = set_with_task_rule(source_unit).communication_rules.first
    target_set = target_unit.communication_sets.create!(name: 'Existing', active: true)
    add_auth_header_for(user: admin)

    get "/api/units/#{source_unit.id}/communication_rules/#{rule.id}/export"

    assert_equal 200, last_response.status
    document = last_response_body

    assert_equal 'ontrack.communication_rule', document['format']

    post_json "/api/units/#{target_unit.id}/communication_sets/#{target_set.id}/rules/import", document: document

    assert_equal 201, last_response.status
    assert_equal 0, last_response_body['report']['unresolved_count']
    assert_equal 'Chase T1.1', last_response_body['rule']['name']
    assert_equal 1, target_set.reload.communication_rules.count
  end

  private

  def unit_with_task(abbreviation)
    unit = FactoryBot.create(
      :unit,
      with_students: false,
      task_count: 0,
      stream_count: 0,
      tutorials: 0,
      outcome_count: 0,
      staff_count: 1,
      campus_count: 1
    )

    unit.task_definitions.create!(
      name: "Task #{abbreviation}",
      abbreviation: abbreviation,
      description: 'Test task',
      weighting: 1,
      target_grade: 0,
      start_date: unit.start_date,
      target_date: unit.start_date + 1.week,
      upload_requirements: []
    )

    unit.reload
  end

  def set_with_task_rule(unit)
    communication_set = unit.communication_sets.create!(name: 'Nudges', active: true)
    rule = communication_set.communication_rules.create!(name: 'Chase T1.1', operator: 'and', position: 0)

    rule.communication_conditions.create!(
      type: 'TaskDefinitionStatusCondition',
      operator: 'equal_to',
      task_definition: unit.task_definitions.first,
      task_statuses: ['not_started']
    )

    rule.communication_actions.create!(
      type: 'EmailStudentAction',
      subject: 'Get started',
      body: 'Hi {{student.first_name}}'
    )

    communication_set
  end
end
