# frozen_string_literal: true

require 'test_helper'

class MoodleIntegrationValidatorTest < ActiveSupport::TestCase
  setup do
    @unit = FactoryBot.create(:unit, with_students: false, moodle_enabled: true)
    @integration = @unit.create_moodle_integration!(
      course_id: 42,
      api_key: 'secret-token',
      group_mapping_enabled: true
    )
  end

  test 'validates when the assignment and every current Moodle group match' do
    create_ignored_mapping(id: 31, name: 'Current group')
    select_assignment(id: 7, name: 'Portfolio')

    result = validate(
      groups: [{ id: 31, name: 'Current group' }],
      assignments: [{ id: 7, name: 'Portfolio' }]
    )

    assert result[:valid]
    assert_empty result[:issues]
    assert @integration.reload.validated?
    assert_not_nil @integration.validated_at
  end

  test 'reports missing and renamed Moodle groups' do
    create_ignored_mapping(id: 31, name: 'Previous name')

    result = validate(
      groups: [
        { id: 31, name: 'Current name' },
        { id: 32, name: 'New group' }
      ]
    )

    assert_not result[:valid]
    assert_equal %w[group_renamed group_missing], result[:issues].pluck(:type)
    assert_not @integration.reload.validated?
    assert_nil @integration.validated_at
  end

  test 'reports mappings whose Moodle group was deleted' do
    create_ignored_mapping(id: 31, name: 'Deleted group')

    result = validate

    assert_not result[:valid]
    assert_equal ['group_deleted'], result[:issues].pluck(:type)
  end

  test 'reports an invalid mapping target' do
    campus = FactoryBot.create(:campus)
    mapping = @integration.moodle_group_mappings.create!(
      moodle_group_id: 31,
      moodle_group_name: 'Campus group',
      target_type: 'campus',
      campus: campus
    )
    mapping.update_column(:campus_id, nil) # rubocop:disable Rails/SkipsModelValidations -- persist invalid legacy data

    result = validate(groups: [{ id: 31, name: 'Campus group' }])

    assert_not result[:valid]
    assert_equal ['group_invalid'], result[:issues].pluck(:type)
    assert_includes result[:issues].first[:message], 'Campus must be selected'
  end

  test 'allows duplicate group mappings and returns a notice' do
    2.times { create_ignored_mapping(id: 31, name: 'Shared group') }

    result = validate(groups: [{ id: 31, name: 'Shared group' }])

    assert result[:valid]
    assert_empty result[:issues]
    assert_equal ['group_duplicate'], result[:notices].pluck(:type)
    assert_includes result[:notices].first[:message], 'all will be applied'
  end

  test 'reports deleted and renamed assignments' do
    select_assignment(id: 7, name: 'Portfolio')

    deleted = validate(assignments: [])
    assert_equal ['assignment_deleted'], deleted[:issues].pluck(:type)

    renamed = validate(assignments: [{ id: 7, name: 'Renamed portfolio' }])
    assert_equal ['assignment_renamed'], renamed[:issues].pluck(:type)
  end

  test 'connection checks invalidate drift without granting validation' do
    create_ignored_mapping(id: 31, name: 'Current group')

    validate(groups: [{ id: 31, name: 'Current group' }], record_success: false)
    assert_not @integration.reload.validated?

    @integration.update!(validated: true, validated_at: Time.current)
    validate(groups: [{ id: 32, name: 'New group' }], record_success: false)
    assert_not @integration.reload.validated?
    assert_nil @integration.validated_at
  end

  private

  def validate(groups: [], assignments: [], record_success: true)
    MoodleIntegrationValidator.new(@integration).validate(
      groups: groups,
      assignments: assignments,
      record_success: record_success
    )
  end

  def create_ignored_mapping(id:, name:)
    @integration.moodle_group_mappings.create!(
      moodle_group_id: id,
      moodle_group_name: name,
      target_type: 'ignore'
    )
  end

  def select_assignment(id:, name:)
    @integration.update!(fetch_extensions: true, assignment_id: id, assignment_name: name)
  end
end
