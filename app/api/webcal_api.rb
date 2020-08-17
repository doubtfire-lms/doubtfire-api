require 'grape'
require 'icalendar'

module Api

  class WebcalApi < Grape::API

    desc 'Serves web calendars ("webcals") that include the target/extension dates of all tasks of students\' active units.'
    params do
      requires :id, type: String, desc: 'The ID of the webcal'
    end
    get '/webcal/:id' do

      # Retrieve the specified webcal.
      webcal = Webcal.find(params[:id])
      ical = Icalendar::Calendar.new

      # Retrieve task definitions and tasks of the user's active units.
      # TODO: Can this be reduced to 1 query instead of 1 + # of projects?
      webcal.user.projects
        .joins(:unit)
        .where(units: { active: true })
        .each do |prj|
          prj.unit.task_definitions.includes(:tasks).where(tasks: { project_id: [prj.id, nil] }).each do |td|

            # Add the task to the iCalendar.
            ical.event do |ev|
              ev.summary = "#{td.unit.code}: #{td.abbreviation}: #{td.name}"
              # The start and end dates should be equal because the calendar event is expected to be an "all-day" event.
              ev.dtstart = Icalendar::Values::Date.new(td.target_date.strftime('%Y%m%d'))
              ev.dtend = Icalendar::Values::Date.new(td.target_date.strftime('%Y%m%d'))
            end

          end
      end

      # Serve the iCalendar with the correct MIME type.
      content_type 'text/calendar'
      ical.to_ical
    end

  end
end
