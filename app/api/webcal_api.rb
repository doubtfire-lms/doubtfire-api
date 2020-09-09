require 'grape'
require 'icalendar'

module Api

  class WebcalApi < Grape::API
    helpers AuthenticationHelpers

    # Declare content types
    content_type :txt, 'text/calendar'

    desc 'Get webcal details of the authenticated user'
    params do
      requires :auth_token, type: String, desc: 'Authentication token'
    end
    get '/webcal' do
      authenticated?
      current_user.webcal
    end

    desc 'Update webcal details of the authenticated user'
    params do
      requires :webcal, type: Hash do
        optional :enabled,             type: Boolean,                                 desc: 'Is the webcal enabled?'
        optional :should_change_guid,  type: Boolean,                                 desc: 'Should the GUID of the webcal be changed?'
        optional :include_start_dates, type: Boolean,                                 desc: 'Should events for start dates be included?'
        optional :unit_exclusions,     type: Array[Integer],                          desc: 'IDs of units that must be excluded from the webcal'

        # `all_or_none_of` is used here instead of 2 `requires` parameters to allow `reminder` to be set to `null`.
        optional :reminder,            type: Hash do
          optional :time,              type: Integer
          optional :unit,              type: String, values: Webcal.valid_time_units, desc: 'w: weeks, d: days, h: hours, m: minutes'
          all_or_none_of :time, :unit
        end
      end
      requires :auth_token, type: String, desc: 'Authentication token'
    end
    put '/webcal' do
      authenticated?
      webcal_params = params[:webcal]

      user = current_user

      cal = Webcal
        .includes(:webcal_unit_exclusions)
        .where(user_id: user.id)
        .load
        .first

      # Create or destroy the user's webcal, according to the `enabled` parameter.
      if webcal_params.key?(:enabled)
        if webcal_params[:enabled] and cal.nil?
          cal = user.create_webcal(guid: SecureRandom.uuid)
        elsif !webcal_params[:enabled] and cal.present?
          cal.destroy
        end
      end

      return if cal.nil? or cal.destroyed?
      webcal_update_params = {}

      # Change the GUID if requested.
      if webcal_params.key?(:should_change_guid)
        webcal_update_params[:guid] = SecureRandom.uuid
      end

      # Change the reminder if requested.
      if webcal_params.key?(:reminder)
        if webcal_params[:reminder].nil?
          webcal_update_params[:reminder_time] = webcal_update_params[:reminder_unit] = nil
        else
          webcal_update_params[:reminder_time] = webcal_params[:reminder][:time]
          webcal_update_params[:reminder_unit] = webcal_params[:reminder][:unit]
        end
      end

      # Set any other properties that have to be updated verbatim.
      webcal_update_params.merge! ActionController::Parameters.new(webcal_params).permit(
        :include_start_dates,
        :reminder_time,
        :reminder_unit
      )

      # Update calendar.
      cal.update! webcal_update_params

      # Update unit exclusions, if specified.
      if webcal_params.key?(:unit_exclusions)

        # Delete existing exclusions.
        cal.webcal_unit_exclusions.destroy_all

        # Add exclusions with valid unit IDs.
        if webcal_params[:unit_exclusions].any?
          cal.webcal_unit_exclusions.create(
            Unit
              .joins(:projects)
              .where(
                projects: { user_id: 7 },
                units: { id: webcal_params[:unit_exclusions], active: true }
              )
              .pluck(:id)
              .map { |i| { unit_id: i } }
          )
        end
      end

      cal
    end

    desc 'Serve webcal with the specified GUID'
    params do
      requires :guid, type: String, desc: 'The GUID of the webcal'
    end
    get '/webcal/:guid' do

      # Retrieve the specified webcal.
      webcal = Webcal.where(guid: params[:guid]).first!

      # Generate iCalendar.
      ical = webcal.to_ical_with_task_definitions(
        # Retrieve task definitions and tasks of the user's current active units.
        TaskDefinition
          .joins(:unit, unit: :projects)
          .eager_load(:tasks)
          .includes(:unit, :tasks, unit: :projects)
          .where(
            projects: { user_id: webcal.user_id },
            units: { active: true }
          )
          .where.not(
            units: { id: WebcalUnitExclusion.where(webcal_id: webcal.id).select(:unit_id) } # exclude :webcal_unit_exclusions
          )
          .where('tasks.project_id is null or tasks.project_id = projects.id')   # eager_load only :tasks of :projects
          .where('? BETWEEN units.start_date AND units.end_date', Time.zone.now) # Current units
          .where('task_definitions.target_grade <= projects.target_grade')       # only :tasks of the targeted_grade or lower
      )

      # Specify refresh interval.
      refresh_interval = Icalendar::Values::Duration.new('1D')
      # https://docs.microsoft.com/en-us/openspecs/exchange_server_protocols/ms-oxcical/1fc7b244-ecd1-4d28-ac0c-2bb4df855a1f
      ical.append_custom_property('X-PUBLISHED-TTL', refresh_interval)
      # https://tools.ietf.org/html/rfc7986#section-5.7
      ical.append_custom_property('REFRESH-INTERVAL', refresh_interval)

      # Serve the iCalendar with the correct MIME type.
      content_type 'text/calendar'
      ical.to_ical
    end

  end
end
