# frozen_string_literal: true

#
# Sets special consideration days from extensions granted on the selected LMS assignment.
#
class ImportLmsExtensionsJob
  include Sidekiq::Job
  include Sidekiq::Status::Worker

  sidekiq_options lock: :until_executed,
                  lock_args_method: ->(args) { [args.first] },
                  on_conflict: :reject,
                  retry: false

  def perform(unit_id, preview_only, scheduled)
    total(2)
    at(0, 'Validating LMS integration')

    unit = Unit.find(unit_id)
    integration = unit.lms_integration
    unless integration&.fetch_extensions? && integration.assignment_id.present?
      raise LtiCourseDataSource::Error, 'Enable extension imports and select an LMS assignment first'
    end

    source = integration.data_source
    LmsIntegrationValidator.new(integration).validate!(
      groups: integration.group_mapping_enabled? ? source.groups : [],
      assignments: source.assignments
    )

    at(1, 'Fetching LMS extensions')
    data = source.assignment_extensions(integration.assignment_id)
    due_date = Time.zone.at(data[:assignment][:due_date]).to_date
    extensions = data[:extensions].select { |extension| extension[:extension_due_date].positive? }
    total(2 + extensions.length)

    result = { success: [], ignored: [], errors: [] }
    extensions.each_with_index do |extension, index|
      extension_date = Time.zone.at(extension[:extension_due_date]).to_date
      row = {
        lms_username: extension[:login_id],
        email: extension[:email],
        extension_date: extension_date.iso8601,
        spec_con_days: nil
      }

      begin
        days = [(extension_date - due_date).to_i, 0].max
        row[:spec_con_days] = days

        user = UserIdentity.find_user(login_id: extension[:login_id], email: extension[:email])
        if user && UserIdentity.blocked?(user, login_id: extension[:login_id], email: extension[:email], source: 'lms_extensions')
          result[:errors] << { row: row, message: "#{user.username} is linked to a different login id" }
          next
        end

        project = user && unit.projects.find_by(user_id: user.id)
        if project.blank?
          result[:ignored] << { row: row, message: 'Student is not enrolled in OnTrack' }
          next
        end

        if project.spec_con_days == days
          result[:ignored] << { row: row, message: 'Special consideration days are unchanged' }
        else
          project.update!(spec_con_days: days) unless preview_only
          message = preview_only ? "Would update special consideration to #{days} days" : "Special consideration updated to #{days} days"
          result[:success] << { row: row, message: message }
        end
      rescue StandardError => e
        result[:errors] << { row: row, message: e.message }
      ensure
        at(2 + index + 1, 'Importing extensions')
      end
    end

    store(result: result.to_json)
    integration&.auto_sync_succeeded! if scheduled
  rescue StandardError => e
    LmsIntegration.find_by(unit_id: unit_id)&.auto_sync_failed!(:extensions, e) if scheduled
    raise
  end
end
