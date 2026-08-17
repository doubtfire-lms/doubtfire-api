class EngagementTracker
  DEBOUNCE = 15.minutes

  def self.record_attendance(user:, project:, occurred_at: Time.zone.now)
    return unless during_enrolled_tutorial?(project, occurred_at)

    record_engagement(
      user: user,
      project: project,
      engagement_type: 'Attendance',
      note: 'Attended tutorial and QR scanned.',
      occurred_at: occurred_at
    )
  end

  def self.record_class_discussion(user:, project:, task_status_updates:, occurred_at: Time.zone.now)
    timing = during_enrolled_tutorial?(project, occurred_at) ? 'during tutorial' : 'outside of tutorial'
    note = if task_status_updates.any?
             status_update_note(timing, task_status_updates)
           else
             "Class discussion #{timing}; no task statuses were updated."
           end

    record_engagement(
      user: user,
      project: project,
      engagement_type: 'Discussion',
      note: note,
      occurred_at: occurred_at
    ) do |recent_engagement|
      merge_status_updates!(recent_engagement, timing, task_status_updates)
    end
  end

  def self.record_engagement(user:, project:, engagement_type:, note:, occurred_at:)
    project.with_lock do
      recent_engagement = recently_recorded(project, engagement_type, occurred_at)
      if recent_engagement
        yield recent_engagement if block_given?
        return
      end

      project.engagements.create!(
        user: user,
        engagement_type: engagement_type,
        note: note,
        occurred_at: occurred_at
      )
    end
  end

  def self.recently_recorded(project, engagement_type, occurred_at)
    project.engagements
           .where('LOWER(engagement_type) = ?', engagement_type.downcase)
           .where(occurred_at: (occurred_at - DEBOUNCE)..occurred_at)
           .order(occurred_at: :desc)
           .first
  end

  def self.status_update_note(timing, task_status_updates)
    ["Updated task statuses #{timing}.", *status_update_sentences(task_status_updates)].join(' ')
  end

  def self.status_update_sentences(task_status_updates)
    task_status_updates.map do |update|
      "#{update[:task]}: #{update[:from]} → #{update[:to]}."
    end
  end

  def self.merge_status_updates!(engagement, timing, task_status_updates)
    updates = status_update_sentences(task_status_updates)
    return if updates.empty?

    if engagement.note.include?('no task statuses were updated')
      engagement.update!(note: status_update_note(timing, task_status_updates))
      return
    end

    new_updates = updates.reject { |update| engagement.note.include?(update) }
    engagement.update!(note: "#{engagement.note} #{new_updates.join(' ')}") if new_updates.any?
  end

  def self.during_enrolled_tutorial?(project, occurred_at)
    project.tutorial_enrolments.includes(tutorial: :campus).any? do |enrolment|
      tutorial = enrolment.tutorial
      timezone = ActiveSupport::TimeZone[tutorial.campus&.timezone] || Time.zone
      local_time = occurred_at.in_time_zone(timezone)

      next false unless tutorial.meeting_day == local_time.strftime('%A')

      tutorial_start = timezone.parse("#{local_time.to_date} #{tutorial.meeting_time}")
      local_time >= tutorial_start && local_time < tutorial_start + tutorial.duration_minutes.minutes
    end
  end

  private_class_method :record_engagement,
                       :recently_recorded,
                       :status_update_note,
                       :status_update_sentences,
                       :merge_status_updates!,
                       :during_enrolled_tutorial?
end
