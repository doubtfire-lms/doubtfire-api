class ExecuteCommunicationSetJob
  include Sidekiq::Job
  include Sidekiq::Status::Worker

  sidekiq_options lock: :until_executed,
                  lock_args_method: ->(args) { [args[0], args[1], 'communication-set'] },
                  on_conflict: :reject,
                  retry: 1

  def perform(communication_set_id, target_rule_id = nil)
    communication_set = CommunicationSet.find(communication_set_id)
    rules = communication_set.communication_rules.to_a
    target_rule_id = target_rule_id&.to_i

    if target_rule_id.present? && rules.none? { |rule| rule.id == target_rule_id }
      raise ActiveRecord::RecordNotFound, "CommunicationRule #{target_rule_id} not found in set #{communication_set_id}"
    end

    eligible_projects = communication_set.eligible_projects
    remaining_projects = eligible_projects.dup
    executed_rules = []
    action_results = []

    rules_to_process =
      if target_rule_id.present?
        cutoff_index = rules.index { |rule| rule.id == target_rule_id }
        rules.first(cutoff_index + 1)
      else
        rules
      end

    at(0)
    total(rules_to_process.length.nonzero? || 1)

    rules_to_process.each_with_index do |rule, index|
      matched_projects = rule.matching_projects(remaining_projects)

      executed_rules << {
        rule_id: rule.id,
        rule_name: rule.name,
        matched_project_ids: matched_projects.map(&:id)
      }

      should_execute_actions = target_rule_id.present? ? rule.id == target_rule_id : true

      if should_execute_actions
        rule.communication_actions.each do |action|
          action_results.concat(execute_action(action, matched_projects, communication_set.unit, rule))
        end
      end

      remaining_projects -= matched_projects
      at(index + 1)
    end

    store(
      result: {
        communication_set_id: communication_set.id,
        target_rule_id: target_rule_id,
        executed_rule_ids: executed_rules.map { |item| item[:rule_id] },
        remaining_project_ids: remaining_projects.map(&:id),
        rules: executed_rules,
        actions: action_results
      }
    )
  rescue StandardError => e
    logger.error("ExecuteCommunicationSetJob failed: #{e.class} #{e.message}")
    raise e
  end

  private

  def execute_action(action, projects, unit, rule)
    case action.type
    when 'ChangeTargetGradeAction'
      execute_change_target_grade_action(action, projects)
    when 'EmailStudentAction'
      execute_email_student_action(action, projects, unit, rule)
    when 'EmailStaffAction'
      execute_email_staff_action(action, projects, unit, rule)
    else
      [{
        action_id: action.id,
        action_type: action.type,
        status: 'skipped',
        reason: 'unsupported action type'
      }]
    end
  end

  def execute_change_target_grade_action(action, projects)
    projects.map do |project|
      previous_target_grade = project.target_grade

      project.update!(target_grade: action.target_grade)

      {
        action_id: action.id,
        action_type: action.type,
        status: 'updated',
        project_id: project.id,
        username: project.user&.username,
        previous_target_grade: previous_target_grade,
        target_grade: action.target_grade
      }
    end
  end

  def execute_email_student_action(action, projects, unit, rule)
    projects.filter_map do |project|
      recipient = project.user
      sender = sender_for(unit)

      if recipient&.email.blank?
        next {
          action_id: action.id,
          action_type: action.type,
          status: 'skipped',
          project_id: project.id,
          reason: 'student email missing'
        }
      end

      if sender.blank?
        next {
          action_id: action.id,
          action_type: action.type,
          status: 'skipped',
          project_id: project.id,
          reason: 'sender email missing'
        }
      end

      subject = render_template(action.subject, project, unit, rule)
      body = render_template(action.body, project, unit, rule)

      CommunicationsMailer.communication_email(
        to: formatted_email(recipient),
        from: sender,
        subject: subject,
        body: body,
        recipient: recipient,
        sender: sender_user_for(unit),
        unit: unit,
        rule: rule
      ).deliver_now

      {
        action_id: action.id,
        action_type: action.type,
        status: 'sent',
        project_id: project.id,
        username: recipient.username,
        recipient_email: recipient.email
      }
    end
  end

  def execute_email_staff_action(action, projects, unit, rule)
    projects.flat_map do |project|
      sender = sender_for(unit)

      if sender.blank?
        next [{
          action_id: action.id,
          action_type: action.type,
          status: 'skipped',
          project_id: project.id,
          username: project.user&.username,
          reason: 'sender email missing'
        }]
      end

      staff_recipients_for(project, unit, action).map do |recipient|
        subject = render_template(action.subject, project, unit, rule)
        body = render_template(action.body, project, unit, rule)

        CommunicationsMailer.communication_email(
          to: formatted_email(recipient),
          from: sender,
          subject: subject,
          body: body,
          recipient: recipient,
          sender: sender_user_for(unit),
          unit: unit,
          rule: rule
        ).deliver_now

        {
          action_id: action.id,
          action_type: action.type,
          status: 'sent',
          project_id: project.id,
          username: project.user&.username,
          recipient_email: recipient.email,
          recipient_username: recipient.username
        }
      end
    end
  end

  def staff_recipients_for(project, unit, action)
    recipients = []

    if action.email_tutors
      recipients.concat(
        project.tutorial_enrolments.filter_map do |tutorial_enrolment|
          tutorial_enrolment.tutorial&.unit_role&.user
        end
      )
    end

    if action.email_convenors
      recipients.concat(unit.convenors.includes(:user).map(&:user))
    end

    recipients.select { |recipient| recipient&.email.present? }.uniq(&:id)
  end

  def render_template(template, project, unit, rule)
    return '' if template.blank?

    student = project.user

    replacements = {
      '{{student.first_name}}' => student&.first_name.to_s,
      '{{student.last_name}}' => student&.last_name.to_s,
      '{{student.preferred_name}}' => (student&.nickname.presence || student&.first_name).to_s,
      '{{student.full_name}}' => [student&.first_name, student&.last_name].compact.join(' '),
      '{{student.username}}' => student&.username.to_s,
      '{{student.student_id}}' => student&.student_id.to_s,
      '{{unit.code}}' => unit.code.to_s,
      '{{unit.name}}' => unit.name.to_s,
      '{{rule.name}}' => rule.name.to_s,
      '{{target_grade}}' => target_grade_name(project.target_grade)
    }

    replacements.reduce(template.dup) do |rendered, (token, value)|
      rendered.gsub(token, value)
    end
  end

  def target_grade_name(value)
    GradeHelper.grade_for(value).to_s
  end

  def formatted_email(user)
    return nil if user&.email.blank?

    %("#{user.name}" <#{user.email}>)
  end

  def sender_for(unit)
    formatted_email(sender_user_for(unit))
  end

  def sender_user_for(unit)
    unit.main_convenor_user || unit.convenors.includes(:user).first&.user
  end
end
