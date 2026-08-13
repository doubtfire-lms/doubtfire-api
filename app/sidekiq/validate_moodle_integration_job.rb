# frozen_string_literal: true

class ValidateMoodleIntegrationJob
  include Sidekiq::Job
  include Sidekiq::Status::Worker

  sidekiq_options lock: :until_executed,
                  lock_args_method: ->(args) { [args.first] },
                  on_conflict: :reject,
                  retry: false

  def perform(unit_id)
    total(2)
    at(0, 'Fetching Moodle groups and assignments')
    unit = Unit.find(unit_id)
    raise MoodleApi::Error, 'Moodle integration is not enabled for this unit' unless unit.moodle_enabled?

    integration = unit.moodle_integration
    raise MoodleApi::Error, 'Configure Moodle for this unit first' if integration.blank?

    moodle = MoodleApi.new(integration)
    groups = moodle.course_groups
    assignments = if integration.fetch_extensions?
                    MoodleIntegrationValidator.assignments_for_course(integration, moodle.assignments)
                  else
                    []
                  end
    result = MoodleIntegrationValidator.new(integration).validate(groups: groups, assignments: assignments)
    at(2, result[:valid] ? 'Moodle integration validated' : 'Moodle integration requires review')
    store(result: result.to_json)
  end
end
