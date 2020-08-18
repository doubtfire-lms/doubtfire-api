require 'grape'
require 'icalendar'

module Api

  class WebcalApi < Grape::API
    content_type :txt, 'text/calendar'

    desc 'Serves web calendars ("webcals") that include selected dates of tasks of students\' active units.'
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
