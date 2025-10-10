class SessionTracker
  THRESHOLD = 15 # minutes

  # TODO: this should accept unit, project.unit could be ambiguous
  def self.record_assessment_activity(action:, user:, project:, ip_address:, task: nil, unit: nil)
    unit = project.unit if project
    role = unit.role_for(user) if unit

    return if role.nil?

    if role != Role.admin && role != Role.convenor && role != Role.tutor
      return
    end

    session = find_or_create_session(user, project.unit, ip_address)

    activity = session.session_activities.create!(
      action: action,
      project_id: project.id,
      task_id: task&.id,
      task_definition_id: task&.task_definition_id,
      created_at: DateTime.now
    )

    session.update_session_details

    activity
  end

  # Finds the most recent active session for the given user/unit/ip.
  # If there's been less than THRESHOLD minutes of inactivity, it returns that session.
  # Otherwise, it creates a new session starting now
  #
  # This means a session can last indefinitely as long as there's been an action within 15 minutes of the previous action
  #
  def self.find_or_create_session(user, unit, ip_address)
    now = Time.zone.now
    session = MarkingSession
              .where(user: user, unit: unit, ip_address: ip_address)
              .where("end_time IS NULL OR end_time > ?", THRESHOLD.minutes.ago)
              .order(start_time: :desc)
              .first

    # Find unit_role
    unit_role = unit.unit_roles.find_by(user: user)
    activity_type = ActivityType.find_by(abbreviation: "Feedback")
    tutorial_streams = unit_role && activity_type ? unit.tutorial_streams.where(activity_type: activity_type) : []
    is_during_tutorial = false

    tutorial_streams.each do |stream|
      tutorials = stream.tutorials.where(unit_role: unit_role)
      tutorials.each do |tutorial|
        # Skip if day does not match
        next if tutorial.meeting_day != now.strftime('%A')

        tutorial_start = Time.zone.parse("#{now.to_date} #{tutorial.meeting_time}")
        tutorial_end   = tutorial_start + 2.hours

        if now >= tutorial_start && now < tutorial_end
          is_during_tutorial = true
        end

        if session.nil? || session.start_time.nil?
          # No session yet, create new one
          session = MarkingSession.create!(
            user: user,
            unit: unit,
            ip_address: ip_address,
            start_time: now,
            during_tutorial: now >= tutorial_start && now < tutorial_end
          )

        elsif session.start_time < tutorial_start && now >= tutorial_start && now < tutorial_end
          # Session before tutorial, but now is during tutorial
          session.update(end_time: tutorial_start - 1.second)
          session = MarkingSession.create!(
            user: user,
            unit: unit,
            ip_address: ip_address,
            start_time: now,
            during_tutorial: true
          )
        elsif session.start_time >= tutorial_start && session.start_time < tutorial_end && now >= tutorial_end
          # Session started during tutorial, now past tutorial
          session.update(end_time: tutorial_end)
          session = MarkingSession.create!(
            user: user,
            unit: unit,
            ip_address: ip_address,
            start_time: now,
            during_tutorial: false
          )
        end
      end
    end

    # Fallback: if still nil, create a session outside tutorial
    session ||= MarkingSession.create!(
      user: user,
      unit: unit,
      ip_address: ip_address,
      start_time: now,
      during_tutorial: false
    )

    session.update(during_tutorial: is_during_tutorial)

    session
  end

  # def self.find_or_create_session(user, unit, ip_address)
  #   session = MarkingSession
  #             .where(user: user, unit: unit, ip_address: ip_address)
  #             .where("end_time IS NULL OR end_time > ?", THRESHOLD.minutes.ago)
  #             .order(start_time: :desc)
  #             .first

  #   now_is_during_tutorial = false

  #   unless session.nil?
  #     # Find the unit role for this user in the unit
  #     # unit_role = unit.role_for(user)
  #     unit_role = unit.unit_roles.find_by(user: user)
  #     unless unit_role.nil?

  #       # Find Feedback tutorial streams
  #       activity_type = ActivityType.find_by(abbreviation: "Feedback")
  #       unless activity_type.nil?

  #         tutorial_streams = unit.tutorial_streams.where(activity_type: activity_type)

  #         # Find a tutorial that the unit role tutors

  #         tutorial_streams.each do |stream|
  #           tutorials = stream.tutorials.where(unit_role: unit_role)
  #           next if tutorials.count == 0
  #           # We have potential tutorials where unit role is a tutor
  #           tutorials.each do |tutorial|
  #             time_str = tutorial.meeting_time # "10:00"
  #             datetime = Time.zone.parse("#{Time.zone.today} #{time_str}") # => 2025-10-10 10:00:00 +0000
  #             current_day_name = Time.zone.now.strftime('%A') # e.g., "Friday"

  #             next if tutorial.meeting_day != current_day_name

  #             tutorial_start = Time.zone.parse("#{Time.zone.today} #{time_str}")
  #             tutorial_end = datetime + 2.hours

  #             # If session.start_time is before the tutorial start time.. and
  #             # If DateTime.now falls within the tutorial allocated time + 2 hours..
  #             if session.start_time < tutorial_start && Time.zone.now >= tutorial_start && Time.zone.now < tutorial_end
  #               # current session is before the tutorial, and current time is during the tutorial
  #               # ..cut `session` end time to 1 second before the tutorial
  #               session_end_before_tutorial = tutorial_start - 1.second
  #               session.update(end_time: session_end_before_tutorial)

  #               # create a new marking session starting from the tutorial time

  #               session = MarkingSession.create!(
  #                 user: user,
  #                 unit: unit,
  #                 ip_address: ip_address,
  #                 start_time: Time.zone.now,
  #                 during_tutorial: true
  #               )
  #             # vice versa
  #             # ..
  #             # .. if session was inside the tutorial time, but DateTime.now is outside of the tutorial time.
  #             # .. cut `sesson end_time` to the end of the tutorial time, and start a new session outside the tutorial
  #             elsif session.start_time >= tutorial_start && session.start_time < tutorial_end && Time.zone.now >= tutorial_end
  #               # Session started during tutorial, current time is now after tutorial
  #               session.update(end_time: tutorial_end)

  #               # Optionally start a new session after the tutorial
  #               session = MarkingSession.create!(
  #                 user: user,
  #                 unit: unit,
  #                 ip_address: ip_address,
  #                 start_time: tutorial_end
  #               )
  #             end
  #           end
  #         end
  #       end

  #     end
  #   end

  #   session ||= MarkingSession.create!(
  #     user: user,
  #     unit: unit,
  #     ip_address: ip_address,
  #     start_time: Time.zone.now
  #   )

  #   session
  # end
end
