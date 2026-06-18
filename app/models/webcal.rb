require 'icalendar'

class Webcal < ApplicationRecord
  belongs_to :user, optional: false

  has_many :webcal_unit_exclusions, dependent: :destroy

  #
  # Array of valid units by which task reminders (alarms) can be set.
  # Documented at https://tools.ietf.org/html/rfc5545#section-3.3.6
  #
  def self.valid_time_units
    %w(W D H M)
  end

  def reminder_trigger
    return nil unless reminder?

    trigger =
      case reminder_unit
      when 'W', 'D'
        "-P#{reminder_time}#{reminder_unit}"
      when 'H', 'M'
        "-PT#{reminder_time}#{reminder_unit}"
      end

    Icalendar::Values::Duration.new(trigger, 'RELATED' => 'START')
  end

  #
  # Represents the presence of `reminder_time` and `reminder_unit`.
  #
  def reminder?
    reminder_time.present? && reminder_unit.present?
  end

  #
  # Retrieves `TaskDefinition`s that must be included in the generation of this webcal.
  # Eager loads most associations used by the `Webcal.to_ical` method -- still need to get the tasks!
  # Currently executes in just 1 SQL query!
  #
  def task_definitions
    TaskDefinition
      .joins(:unit, unit: :projects)
      .includes(:grade_due_dates, unit: :projects)
      .where(
        projects: { user_id: user_id, enrolled: true },
        units: { active: true }
      )
      .where.not(
        units: { id: WebcalUnitExclusion.where(webcal_id: id).select(:unit_id) } # exclude :webcal_unit_exclusions
      )
      .where('? BETWEEN units.start_date AND units.end_date', Time.zone.now) # Current units
      .where('task_definitions.target_grade <= projects.target_grade')       # only :tasks of the targeted_grade or lower
  end

  #
  # Retrieves the event name for the specified task definition in the calendar.
  # Valid values for `variant` are,
  #   - 'start' retrieves the name for the _start event_
  #   - 'end' (default) retrieves the name for the _end event_
  #
  def event_name_for_task_definition(task_def, variant = 'end')
    name = "#{task_def.unit.code}: #{task_def.abbreviation}: #{task_def.name}"
    case variant
    when 'start' then "Start: #{name}"
    when 'end'   then (include_start_dates ? "End: #{name}" : name)
    end
  end

  #
  # Generates a single `Icalendar::Calendar` object from this `Webcal` including calendar events for the specified
  # collection of `TaskDefinition`s.
  #
  # The `unit` property of each `TaskDefinition` is accessed; ensure it is included to prevent N+1 selects. For example,
  #
  #   to_ical_with_task_definitions(
  #     TaskDefinition
  #       .joins(:unit)
  #       .includes(:unit)
  #   )
  #
  def to_ical(task_defs = task_definitions)
    ical = Icalendar::Calendar.new
    ical.publish
    ical.prodid = Doubtfire::Application.config.institution[:product_name]

    projects = Project
               .includes(:unit)
               .where(user_id: user_id, enrolled: true, unit_id: task_defs.map(&:unit_id).uniq)
               .index_by(&:unit_id)

    tasks = Task
            .includes(:project, task_definition: :grade_due_dates)
            .where(task_definition: task_defs, project: projects.values)
            .index_by(&:task_definition_id)

    # Add iCalendar events for the specified definition.
    task_defs.each do |td|
      # Notes:
      # - Start and end dates of events are equal because the calendar event is expected to be an "all-day" event.
      # - iCalendar clients identify events across syncs by their UID property, which is currently the task definition
      #   ID prefixed with S- or E- based on whether it is a start or end event.

      ev_date_format = '%Y%m%d'
      ev_reminders = reminder?
      ev_reminder_trigger = reminder_trigger

      # Add event for start date, if the user opted in.
      if include_start_dates
        ical.event do |ev|
          ev.uid = "S-#{td.id}"
          ev.summary = event_name_for_task_definition(td, 'start')
          ev.status = 'CONFIRMED'
          start_date = Webcal.start_date_for_task_definition(td, tasks[td.id], projects[td.unit_id])
          ev.dtstart = ev.dtend = Icalendar::Values::Date.new(start_date.strftime(ev_date_format))

          Webcal.add_metadata_to_ical_event(ev, td)

          if ev_reminders
            ev.alarm do |a|
              a.action = 'DISPLAY'
              a.description = ev.summary
              a.trigger = ev_reminder_trigger
            end
          end
        end
      end

      # Add event for target/extended date.
      ical.event do |ev|
        ev.uid = "E-#{td.id}"
        ev.summary = event_name_for_task_definition(td, 'end')
        ev.status = 'CONFIRMED'
        end_date = Webcal.end_date_for_task_definition(td, tasks[td.id], projects[td.unit_id])
        ev.dtstart = ev.dtend = Icalendar::Values::Date.new(end_date.strftime(ev_date_format))

        Webcal.add_metadata_to_ical_event(ev, td)

        if ev_reminders
          ev.alarm do |a|
            a.action = 'DISPLAY'
            a.description = ev.summary
            a.trigger = ev_reminder_trigger
          end
        end
      end
    end

    # Specify refresh interval.
    refresh_interval = Icalendar::Values::Duration.new('1D')
    # https://docs.microsoft.com/en-us/openspecs/exchange_server_protocols/ms-oxcical/1fc7b244-ecd1-4d28-ac0c-2bb4df855a1f
    ical.append_custom_property('X-PUBLISHED-TTL', refresh_interval)
    # https://tools.ietf.org/html/rfc7986#section-5.7
    ical.append_custom_property('REFRESH-INTERVAL', refresh_interval)

    ical
  end

  #
  # Returns the target/extended date for the specified task definition.
  #
  def self.end_date_for_task_definition(task_def, task = nil, project = nil)
    return task.local_due_date if task.present?

    flexible_grade_date_for_task_definition(task_def, project, :target_date) || task_def.target_date
  end

  #
  # Returns the start date for the specified task definition.
  #
  def self.start_date_for_task_definition(task_def, task = nil, project = nil)
    return task.local_start_date if task.present?

    flexible_grade_date_for_task_definition(task_def, project, :start_date) || task_def.start_date
  end

  def self.flexible_grade_date_for_task_definition(task_def, project, date_type)
    return nil unless project&.unit&.allow_flexible_dates

    case [project.target_grade, date_type]
    when [1, :target_date] then task_def.c_target_date
    when [2, :target_date] then task_def.d_target_date
    when [3, :target_date] then task_def.hd_target_date
    when [1, :start_date] then task_def.c_start_date
    when [2, :start_date] then task_def.d_start_date
    when [3, :start_date] then task_def.hd_start_date
    end
  end

  #
  # Hydrates `Icalendar::Event`s with Doutbfire-specific metadata.
  #
  def self.add_metadata_to_ical_event(event, task_def)
    event.append_custom_property('X-DOUBTFIRE-UNIT', task_def.unit.id.to_s)
    event.append_custom_property('X-DOUBTFIRE-TASK', task_def.id.to_s)
  end

  #
  # Retrieves Doubtfire-specific metadata from `Icalendar::Event`s previously hydrated via `add_metadata_to_ical_event`.
  #
  def self.get_metadata_for_ical_event(event)
    return {
      unit_id: event.custom_property('X-DOUBTFIRE-UNIT').first.to_i,
      task_definition_id: event.custom_property('X-DOUBTFIRE-TASK').first.to_i,
    }
  end
end
