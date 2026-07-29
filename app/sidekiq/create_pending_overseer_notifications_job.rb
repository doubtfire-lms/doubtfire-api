# frozen_string_literal: true

class CreatePendingOverseerNotificationsJob
  include Sidekiq::Job

  sidekiq_options lock: :until_executed,
                  lock_args_method: ->(_args) { ['create-pending-overseer-notifications'] },
                  on_conflict: :reject,
                  retry: 1

  def perform
    OverseerAssessment.awaiting_student_failure_notification.find_each do |assessment|
      Notification.create_for_overseer(assessment)
      assessment.update!(student_notified_at: Time.current)
    end
  end
end
