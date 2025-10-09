class SessionTracker
  THRESHOLD = 15 # minutes

  def self.record_assessment_activity(action:, user:, project:, ip_address:, task: nil)
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
    session = MarkingSession
              .where(user: user, unit: unit, ip_address: ip_address)
              .where("end_time IS NULL OR end_time > ?", THRESHOLD.minutes.ago)
              .order(start_time: :desc)
              .first

    session ||= MarkingSession.create!(
      user: user,
      unit: unit,
      ip_address: ip_address,
      start_time: DateTime.now
    )

    session
  end
end
