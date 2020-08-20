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
        optional :enabled,             type: Boolean, desc: 'Is the webcal enabled?'
        optional :should_change_id,    type: Boolean, desc: 'Should the ID of the webcal be changed?'
        optional :include_start_dates, type: Boolean, desc: 'Should events for start dates be included?'
      end
      requires :auth_token, type: String, desc: 'Authentication token'
    end
    put '/webcal' do
      authenticated?
      webcal_params = params[:webcal]

      user = current_user
      cal = user.webcal

      # Create or destroy the user's webcal, according to the `enabled` parameter.
      if webcal_params.key?(:enabled)
        if webcal_params[:enabled] and cal.nil?
          cal = user.create_webcal(id: SecureRandom.uuid)
        elsif !webcal_params[:enabled] and cal.present?
          cal.destroy
        end
      end

      return if cal.nil? or cal.destroyed?
      webcal_update_params = {}

      # Change the ID if requested.
      if webcal_params.key?(:should_change_id)
        webcal_update_params[:id] = SecureRandom.uuid
      end

      # Set any other properties that have to be updated verbatim.
      webcal_update_params.merge! ActionController::Parameters.new(webcal_params).permit(
        :include_start_dates
      )

      # Update and return calendar.
      cal.update! webcal_update_params
      cal
    end

    desc 'Serve webcal with the specified ID'
    params do
      requires :id, type: String, desc: 'The ID of the webcal'
    end
    get '/webcal/:id' do

      # Retrieve the specified webcal.
      webcal = Webcal.find(params[:id])

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
          .where('? BETWEEN units.start_date AND units.end_date', Time.zone.now)
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
