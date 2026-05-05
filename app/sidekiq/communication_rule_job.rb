# require_dependency Rails.root.join('app/models/communication/communication_condition').to_s
# require_dependency Rails.root.join('app/models/communication/target_grade_condition').to_s
# require_dependency Rails.root.join('app/models/communication/task_definition_status_condition').to_s
# require_dependency Rails.root.join('app/models/communication/login_status_condition').to_s
# require_dependency Rails.root.join('app/models/communication/tutorial_enrolment_condition').to_s
# require_dependency Rails.root.join('app/models/communication/tutorial_stream_enrolment_condition').to_s
# require_dependency Rails.root.join('app/models/communication/campus_condition').to_s
# require_dependency Rails.root.join('app/models/communication/communication_action').to_s
# require_dependency Rails.root.join('app/models/communication/email_student_action').to_s
# require_dependency Rails.root.join('app/models/communication/email_staff_action').to_s
# require_dependency Rails.root.join('app/models/communication/change_target_grade_action').to_s
# require_dependency Rails.root.join('app/models/communication/communication_rule').to_s

class CommunicationRuleJob
  include Sidekiq::Job
  include Sidekiq::Status::Worker
  include LogHelper
  include ApplicationHelper
  include FileHelper

  sidekiq_options lock: :until_executed,
                  lock_args_method: ->(args) { [args.first, args.last, 'communication-rule'] },
                  on_conflict: :reject,
                  retry: 1

  def perform(rule_id)
    logger.info "Starting communication rule job..."

    at(0)
    total(1)

    rule = CommunicationRule.find(rule_id)

    projects = rule.communication_set.preview_projects_for_rule(rule)
    store(
      result: projects.map do |project|
        {
          username: project.user&.username,
          student_id: project.user&.student_id,
          target_grade: project.target_grade,
          last_sign_in_at: project.user&.last_sign_in_at
        }
      end
    )

    logger.info "Completed communiation job"
  rescue StandardError => e
    logger.error e
    raise e
  end

end
