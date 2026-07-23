class EngagementTracker
  DEBOUNCE = 15.minutes
  TUTORIAL_DURATION = 2.hours

  def self.record_attendance(user:, project:, occurred_at: Time.zone.now)
    record_during_tutorial(
      user: user,
      project: project,
      engagement_type: 'Attendance',
      note: 'Attended tutorial and QR scanned.',
      occurred_at: occurred_at
    )
  end

  def self.record_during_tutorial(user:, project:, engagement_type:, note:, occurred_at:)
    return unless during_enrolled_tutorial?(project, occurred_at)

    project.with_lock do
      return if recently_recorded?(project, engagement_type, occurred_at)

      project.engagements.create!(
        user: user,
        engagement_type: engagement_type,
        note: note,
        occurred_at: occurred_at
      )
    end
  end

  def self.recently_recorded?(project, engagement_type, occurred_at)
    project.engagements
           .where('LOWER(engagement_type) = ?', engagement_type.downcase)
           .where(occurred_at: (occurred_at - DEBOUNCE)..occurred_at)
           .exists?
  end

  def self.during_enrolled_tutorial?(project, occurred_at)
    project.tutorial_enrolments.includes(tutorial: :campus).any? do |enrolment|
      tutorial = enrolment.tutorial
      timezone = ActiveSupport::TimeZone[tutorial.campus&.timezone] || Time.zone
      local_time = occurred_at.in_time_zone(timezone)

      next false unless tutorial.meeting_day == local_time.strftime('%A')

      tutorial_start = timezone.parse("#{local_time.to_date} #{tutorial.meeting_time}")
      local_time >= tutorial_start && local_time < tutorial_start + TUTORIAL_DURATION
    end
  end

  private_class_method :record_during_tutorial, :recently_recorded?, :during_enrolled_tutorial?
end
