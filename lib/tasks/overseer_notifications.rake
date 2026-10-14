namespace :overseer_notifications do
  def notify_failed_overseer_assessments!
    assessments = OverseerAssessment
                  .awaiting_student_failure_notification
                  .includes(task: [{ project: :unit }, :task_definition])

    assessments.group_by(&:project).each do |project, project_assessments|
      tasks = project_assessments.map(&:task).uniq
      mark_notified = -> { project_assessments.each { |assessment| assessment.update!(student_notified_at: Time.current) } }

      # The student may have switched this email off, or muted the unit. Mark them
      # notified anyway, so they are not reconsidered every ten minutes.
      unless NotificationSetting.for(project.student).delivers?(project.unit, 'overseer_failed', :email)
        mark_notified.call
        next
      end

      begin
        mail = PortfolioEvidenceMailer.overseer_assessment_failed(project, tasks)
        next if mail.blank?

        mail.deliver_now
        mark_notified.call
      rescue StandardError => e
        Rails.logger.error "Failed to send overseer assessment email for project #{project.id}!\n#{e.message}"
      end
    end
  end

  desc 'Send overdue overseer assessment failure notifications to students'
  task send_failed_assessment_notifications: [:environment] do
    notify_failed_overseer_assessments!
  end
end
