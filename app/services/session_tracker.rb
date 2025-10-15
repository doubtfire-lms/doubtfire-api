class SessionTracker
  THRESHOLD = 15 # minutes

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
      created_at: Time.zone.now
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
      # TODO: tutorial stream refactor should have an option whether or not to this stream should be used to split marking sessions
      next if stream.name == "D/HD Feedback"

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
end
