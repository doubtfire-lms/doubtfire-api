# frozen_string_literal: true

class TestMoodleConnectionJob
  include Sidekiq::Job
  include Sidekiq::Status::Worker

  sidekiq_options lock: :until_executed,
                  lock_args_method: ->(args) { [args.first] },
                  on_conflict: :reject,
                  retry: false

  def perform(unit_id)
    total(5)
    at(0, 'Starting Moodle connection test')

    unit = Unit.find(unit_id)
    raise MoodleApi::Error, 'Moodle integration is not enabled for this unit' unless unit.moodle_enabled?

    integration = unit.moodle_integration
    raise MoodleApi::Error, 'Configure Moodle for this unit first' if integration.blank?
    result = MoodleApi.new(integration).test_connection(
      progress_callback: ->(completed, message) { at(completed, message) }
    )
    groups_loaded = result[:permissions].any? do |permission|
      permission[:function] == 'core_group_get_course_groups' && permission[:success]
    end
    assignments_loaded = result[:permissions].any? do |permission|
      permission[:function] == 'mod_assign_get_assignments' && permission[:success]
    end
    if groups_loaded && (!integration.fetch_extensions? || assignments_loaded)
      MoodleIntegrationValidator.new(integration).validate(
        groups: result[:groups],
        assignments: result[:assignments],
        record_success: false
      )
    else
      integration.update!(validated: false, validated_at: nil)
    end

    store(result: result.to_json)
  end
end
