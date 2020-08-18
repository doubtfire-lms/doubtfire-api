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
        if webcal_params[:enabled] and cal == nil
          cal = user.create_webcal(id: SecureRandom.uuid)
        elsif (not webcal_params[:enabled]) and cal != nil
          cal.destroy
        end
      end

      return if cal == nil or cal.destroyed?
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
      ical = Icalendar::Calendar.new

      # Retrieve task definitions and tasks of the user's active units.
      TaskDefinition
          .eager_load(:tasks)
          .joins(unit: :projects)
          .where(
            projects: { user_id: 7 },
            units: { active: true }
          )
          .each do |td|
            # Note: Start and end dates of events are equal because the calendar event is expected to be an "all-day" event.

            ev_name = "#{td.unit.code}: #{td.abbreviation}: #{td.name}"

            # Add event for start date, if the user opted in.
            if webcal.include_start_dates
              ical.event do |ev|
                ev.summary = "Start: #{ev_name}"
                ev.dtstart = ev.dtend = Icalendar::Values::Date.new(td.start_date.strftime('%Y%m%d'))
              end
            end

            # Add event for target/extended date.
            # TODO: Use extension date if available.
            ical.event do |ev|
              ev.summary = "#{webcal.include_start_dates ? "End:" : ""}#{ev_name}"
              ev.dtstart = ev.dtend = Icalendar::Values::Date.new(td.target_date.strftime('%Y%m%d'))
            end

      end

      # Serve the iCalendar with the correct MIME type.
      content_type 'text/calendar'
      ical.to_ical
    end

  end
end
