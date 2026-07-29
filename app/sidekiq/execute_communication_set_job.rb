require 'csv'

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
        rule_action_results = rule.communication_actions.flat_map do |action|
          execute_action(action, matched_projects, communication_set.unit, rule)
        end

        action_results.concat(rule_action_results)
        if rule.send_log_to_convenors?
          action_results.concat(
            send_action_log_to_convenors(
              matched_projects,
              communication_set.unit,
              rule,
              rule_action_results
            )
          )
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
    when 'TaskCommentAction'
      execute_task_comment_action(action, projects, unit, rule)
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

      subject = render_template(action.subject, project, unit, rule, projects.length)
      body = render_template(action.body, project, unit, rule, projects.length)

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
        subject = render_template(action.subject, project, unit, rule, projects.length)
        body = render_template(action.body, project, unit, rule, projects.length)

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

  def execute_task_comment_action(action, projects, unit, rule)
    comment_author = sender_user_for(unit)

    if comment_author.blank?
      return [{
        action_id: action.id,
        action_type: action.type,
        status: 'skipped',
        reason: 'comment author missing'
      }]
    end

    comment_text_template = action.body.to_s.strip

    projects.map do |project|
      task_definition = action.task_definition || unit.task_definitions.find_by(id: action.task_definition_id)
      if task_definition.blank?
        next {
          action_id: action.id,
          action_type: action.type,
          status: 'skipped',
          project_id: project.id,
          username: project.user&.username,
          reason: 'task definition missing'
        }
      end

      task = project.task_for_task_definition(task_definition)
      rendered_comment = render_template(comment_text_template, project, unit, rule, projects.length)

      if rendered_comment.blank?
        next {
          action_id: action.id,
          action_type: action.type,
          status: 'skipped',
          project_id: project.id,
          username: project.user&.username,
          reason: 'comment text missing'
        }
      end

      comment = task.add_text_comment(comment_author, rendered_comment, attention_audience: :student)

      if comment.nil?
        next {
          action_id: action.id,
          action_type: action.type,
          status: 'skipped',
          project_id: project.id,
          username: project.user&.username,
          reason: 'duplicate comment'
        }
      end

      {
        action_id: action.id,
        action_type: action.type,
        status: 'commented',
        project_id: project.id,
        username: project.user&.username,
        task_definition_id: task_definition.id,
        task_definition_name: task_definition.name,
        comment_id: comment.id
      }
    end
  end

  def send_action_log_to_convenors(projects, unit, rule, prior_action_results)
    sender = sender_for(unit)

    if sender.blank?
      return [{
        action_id: nil,
        action_type: 'SendLogToConvenors',
        status: 'skipped',
        reason: 'sender email missing'
      }]
    end

    recipients = unit.convenors.includes(:user).map(&:user).select { |user| user&.email.present? }.uniq(&:id)

    if recipients.empty?
      return [{
        action_id: nil,
        action_type: 'SendLogToConvenors',
        status: 'skipped',
        reason: 'convenor email missing'
      }]
    end

    csv_content = build_action_log_csv(rule, projects, prior_action_results)
    csv_filename = "communication-rule-#{rule.id}-action-log.csv"
    body = action_log_email_body(rule, prior_action_results)
    subject = action_log_email_subject(unit, rule)

    recipients.map do |recipient|
      CommunicationsMailer.action_log_email(
        to: formatted_email(recipient),
        from: sender,
        subject: subject,
        body: body,
        recipient: recipient,
        sender: sender_user_for(unit),
        unit: unit,
        rule: rule,
        csv_content: csv_content,
        csv_filename: csv_filename,
        affected_students_count: projects.length
      ).deliver_now

      {
        action_id: nil,
        action_type: 'SendLogToConvenors',
        status: 'sent',
        recipient_email: recipient.email,
        recipient_username: recipient.username,
        attachment_filename: csv_filename,
        affected_students_count: projects.length
      }
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

  def render_template(template, project, unit, rule, affected_students_count, target_grade_override = nil, action_results = [])
    return '' if template.blank?

    student = project&.user
    target_grade_value = target_grade_override.nil? ? project&.target_grade : target_grade_override

    replacements = {
      '{{student.first_name}}' => student&.first_name.to_s,
      '{{student.last_name}}' => student&.last_name.to_s,
      '{{student.preferred_name}}' => (student&.nickname.presence || student&.first_name).to_s,
      '{{student.full_name}}' => [student&.first_name, student&.last_name].compact.join(' '),
      '{{student.username}}' => student&.username.to_s,
      '{{student.student_id}}' => student&.student_id.to_s,
      '{{affected_students_count}}' => affected_students_count.to_s,
      '{{unit.code}}' => unit.code.to_s,
      '{{unit.name}}' => unit.name.to_s,
      '{{rule.name}}' => rule.name.to_s,
      '{{target_grade}}' => target_grade_name(target_grade_value, unit),
      '{{conditions_summary}}' => conditions_summary(rule),
      '{{actions_summary}}' => actions_summary(rule, action_results)
    }

    replacements.reduce(template.dup) do |rendered, (token, value)|
      rendered.gsub(token, value)
    end
  end

  def target_grade_name(value, unit = nil)
    (unit&.grade_label(value) || GradeHelper.grade_for(value)).to_s
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

  def conditions_summary(rule)
    rule.communication_conditions.map do |condition|
      "- #{human_condition_summary(condition)}"
    end.join("\n")
  end

  def actions_summary(rule, action_results)
    return rule.communication_actions.map { |action| "- #{human_action_summary(action)}" }.join("\n") if action_results.blank?

    rule.communication_actions.map { |action| "- #{human_action_summary(action)}" }.join("\n")
  end

  def build_action_log_csv(rule, projects, action_results)
    action_order = rule.communication_actions.each_with_index.to_h { |action, index| [action.id, index] }
    ordered_results = action_results.sort_by do |result|
      project = projects.find { |item| item.id == result[:project_id] }
      student = project&.user

      [
        student&.username.to_s,
        action_order.fetch(result[:action_id], Float::INFINITY),
        result[:recipient_email].to_s
      ]
    end

    CSV.generate(headers: true) do |csv|
      csv << [
        'student_username',
        'student_id',
        'student_name',
        'rule_name',
        'action_type',
        'status',
        'details',
        # 'previous_target_grade',
        # 'new_target_grade',
        'recipient_email',
        'executed_at'
      ]

      ordered_results.each do |result|
        project = projects.find { |item| item.id == result[:project_id] }
        student = project&.user
        details = if result[:status] == 'updated'
                    "Changed target grade from #{target_grade_name(result[:previous_target_grade], rule.unit)} to #{target_grade_name(result[:target_grade], rule.unit)}"
                  elsif result[:status] == 'commented'
                    task_definition = TaskDefinition.find_by(id: result[:task_definition_id])
                    "Added comment to #{task_definition_label(task_definition)}"
                  elsif result[:recipient_email].present?
                    "Sent email to #{result[:recipient_email]}"
                  else
                    result[:reason].to_s
                  end

        csv << [
          student&.username,
          student&.student_id,
          student&.name,
          rule.name,
          result[:action_type],
          result[:status],
          details,
          # target_grade_name(result[:previous_target_grade]),
          # target_grade_name(result[:target_grade]),
          result[:recipient_email],
          Time.current.iso8601
        ]
      end
    end
  end

  def action_log_email_subject(unit, rule)
    "#{unit.code} #{rule.name} action log"
  end

  def action_log_email_body(rule, action_results)
    [
      action_log_conditions_intro(rule),
      conditions_summary(rule),
      'The following actions have been applied to these students:',
      actions_summary(rule, action_results)
    ].join("\n")
  end

  def action_log_conditions_intro(rule)
    if rule.operator == 'or'
      'A scheduled rule has been run for students that match any of the following conditions:'
    else
      'A scheduled rule has been run for students that match all of the following conditions:'
    end
  end

  def human_condition_summary(condition)
    case condition.type
    when 'TaskDefinitionStatusCondition'
      predicate = condition.operator == 'not_equal_to' ? 'Not In' : 'In'
      task = TaskDefinition.find_by(id: condition.task_definition_id)
      task_label = if task
                     "Task #{task.abbreviation} #{task.name}"
                   else
                     "Task #{condition.task_definition_id}"
                   end
      "Students that have #{task_label} #{predicate} [#{Array(condition.task_statuses).map { |status| status.to_s.titleize }.join(', ')}]"
    when 'TargetGradeCondition'
      "Students with a Target Grade #{operator_label(condition.operator)} #{target_grade_name(condition.target_grade, condition.communication.unit)}"
    when 'TaskStatusCountCondition'
      grade_label = target_grade_name(condition.task_target_grade, condition.communication.unit)
      statuses = Array(condition.task_statuses).map { |status| status.to_s.titleize }.join(', ')
      "Students that have #{operator_label(condition.operator)} #{condition.task_status_count} #{grade_label} tasks in [#{statuses}]"
    when 'LoginStatusCondition'
      relative_activity_summary(condition, 'signed in')
    when 'UnitViewedStatusCondition'
      relative_activity_summary(condition, 'viewed this unit')
    when 'SpecConCondition'
      "Students with Special Consideration Days #{operator_label(condition.operator)} #{condition.spec_con_days}"
    when 'TutorialEnrolmentCondition'
      tutorial = Tutorial.find_by(id: condition.tutorial_id)
      tutorial_label =
        if tutorial
          [tutorial.abbreviation, tutorial.name].compact.join(' ')
        else
          "Tutorial #{condition.tutorial_id}"
        end
      "Students #{enrolment_label(condition.operator).downcase} #{tutorial_label}"
    when 'TutorialStreamEnrolmentCondition'
      tutorial_stream = TutorialStream.find_by(id: condition.tutorial_stream_id)
      stream_label =
        if tutorial_stream
          [tutorial_stream.abbreviation, tutorial_stream.name].compact.join(' ')
        else
          "Tutorial Stream #{condition.tutorial_stream_id}"
        end
      "Students #{enrolment_label(condition.operator).downcase} #{stream_label}"
    when 'CampusCondition'
      campus = Campus.find_by(id: condition.campus_id)
      campus_label = campus&.name || "Campus #{condition.campus_id}"
      "Students #{enrolment_label(condition.operator).downcase} #{campus_label}"
    else
      "#{condition.type.to_s.underscore.humanize} #{condition.operator.to_s.humanize}"
    end
  end

  def relative_activity_summary(condition, activity)
    duration = "#{condition.activity_days} #{'day'.pluralize(condition.activity_days)}"

    if condition.operator == 'more_than'
      "Students who have not #{activity} for more than #{duration}"
    else
      "Students who #{activity} within the last #{duration}"
    end
  end

  def human_action_summary(action)
    case action.type
    when 'EmailStudentAction'
      'Send email'
    when 'EmailStaffAction'
      'Send staff email'
    when 'ChangeTargetGradeAction'
      "Change Target Grade to #{target_grade_name(action.target_grade, action.communication_rule.unit)}"
    when 'TaskCommentAction'
      "Add comment to #{task_definition_label(action.task_definition)}"
    else
      human_action_type_name(action.type)
    end
  end

  def human_action_type_name(type)
    case type
    when 'EmailStudentAction'
      'Send email'
    when 'EmailStaffAction'
      'Send staff email'
    when 'ChangeTargetGradeAction'
      'Change target grade'
    when 'TaskCommentAction'
      'Add task comment'
    else
      type.to_s.underscore.humanize
    end
  end

  def operator_label(operator)
    case operator.to_s
    when 'greater_than'
      'Greater Than'
    when 'greater_than_or_equal_to'
      'Greater Than Or Equal To'
    when 'less_than'
      'Less Than'
    when 'less_than_or_equal_to'
      'Less Than Or Equal To'
    when 'equal_to'
      'Equal To'
    when 'not_equal_to'
      'Not Equal To'
    else
      operator.to_s.humanize
    end
  end

  def enrolment_label(operator)
    operator.to_s == 'not_enrolled_in' ? 'Not Enrolled In' : 'Enrolled In'
  end

  def task_definition_label(task_definition)
    return 'Task' if task_definition.blank?

    "Task #{task_definition.abbreviation} #{task_definition.name}"
  end
end
