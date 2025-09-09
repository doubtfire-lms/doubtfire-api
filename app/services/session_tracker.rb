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

  def self.find_or_create_session(user, unit, ip_address)
    session = MarkingSession.where(
      marker: user,
      unit: unit,
      ip_address: ip_address
    ).where("start_time > ?", THRESHOLD.minutes.ago).last

    if session.nil?
      # Find the last session for this user/unit/ip and end it at 15 minutes
      last_session = MarkingSession.where(
        marker: user,
        unit: unit,
        ip_address: ip_address
      ).order(start_time: :desc).first

      if last_session && last_session.end_time.nil?
        end_time = last_session.start_time + THRESHOLD.minutes
        last_session.update(
          end_time: end_time,
          duration_minutes: THRESHOLD
        )
      end

      session = MarkingSession.create!(
        marker: user,
        unit: unit,
        ip_address: ip_address,
        start_time: DateTime.now
      )
    end

    session
  end
end
