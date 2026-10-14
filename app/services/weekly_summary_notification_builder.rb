# frozen_string_literal: true

class WeeklySummaryNotificationBuilder
  COMMENT_TYPES = %i[text assessment audio image pdf discussion extension].freeze

  def self.for_student(project, summary_stats, did_revert_to_pass: false)
    week_start = summary_stats.fetch(:week_start)
    week_end = summary_stats.fetch(:week_end)
    engagements = project.task_engagements.where(engagement_time: week_start...week_end)
    student_statuses = [
      TaskStatus.not_started.name,
      TaskStatus.need_help.name,
      TaskStatus.working_on_it.name,
      TaskStatus.ready_for_feedback.name
    ]

    {
      audience: 'student',
      week_start: week_start.iso8601,
      week_end: week_end.iso8601,
      unit_comments: summary_stats.fetch(:unit_week_comments),
      unit_task_activity: summary_stats.fetch(:unit_week_engagements),
      sent_comments: project.comments.where(user_id: project.user_id, created_at: week_start...week_end).count,
      received_comments: project.comments.where(recipient_id: project.user_id, created_at: week_start...week_end).count,
      task_activity: engagements.count,
      student_task_activity: engagements.where(engagement: student_statuses).count,
      tutor_allocated: project.tutorial_enrolments.exists?,
      did_revert_to_pass: did_revert_to_pass,
      portfolio_exists: project.portfolio_exists?,
      top_tasks: student_top_tasks(project)
    }
  end

  def self.for_staff(unit_role, summary_stats)
    unit = summary_stats.fetch(:unit)
    staff = unit_role.user
    week_start = summary_stats.fetch(:week_start)
    week_end = summary_stats.fetch(:week_end)
    staff_stats = summary_stats.fetch(:staff).fetch(staff)

    data = {
      audience: 'staff',
      week_start: week_start.iso8601,
      week_end: week_end.iso8601,
      has_students: unit_role.has_students?,
      is_convenor: unit_role.is_convenor?,
      unit_comments: summary_stats.fetch(:unit_week_comments),
      unit_task_activity: summary_stats.fetch(:unit_week_engagements),
      received_comments: unit.comments.where(
        recipient_id: staff.id,
        created_at: week_start...week_end,
        content_type: COMMENT_TYPES
      ).count,
      sent_comments: unit.comments.where(
        user_id: staff.id,
        created_at: week_start...week_end,
        content_type: COMMENT_TYPES
      ).count,
      student_task_activity: staff_stats.fetch(:weekly_engagements_count),
      assessed_tasks: staff_stats.fetch(:staff_engagements),
      discussed_tasks: staff_stats.fetch(:weekly_total_tasks_discussed),
      awaiting_feedback: staff_stats.fetch(:tasks_awaiting_feedback_count),
      oldest_task_days: staff_stats.fetch(:oldest_task_days),
      reverted_students: Array(summary_stats.dig(:revert, staff)).map { |project| project.student.name }
    }

    if unit_role.is_convenor?
      data[:reverted_student_count] = summary_stats.fetch(:revert_count)
      data[:tutorial_streams] = convenor_tutorial_streams(summary_stats)
    end

    data
  end

  def self.student_top_tasks(project)
    project.top_tasks.map do |top_task|
      definition = top_task.fetch(:task_definition)
      {
        abbreviation: definition.abbreviation,
        name: definition.name,
        reason: top_task.fetch(:reason).to_s,
        reason_label: { overdue: 'Overdue', soon: 'Due soon', ahead: 'Get ahead' }.fetch(
          top_task.fetch(:reason),
          top_task.fetch(:reason).to_s.humanize
        ),
        status: top_task[:status]&.to_s
      }
    end
  end
  private_class_method :student_top_tasks

  def self.convenor_tutorial_streams(summary_stats)
    summary_stats.fetch(:tutorial_streams).filter_map do |stream, stream_data|
      next unless stream_data[:stream_linked_to_task_definition]

      rows = Array(stream_data[:unit_roles]).filter_map do |unit_role, data|
        next unless data[:number_of_students].to_i.positive?

        {
          tutor_name: unit_role.user.name,
          students: data[:number_of_students],
          total_assessments: data[:total_staff_engagements],
          weekly_assessments: data[:staff_engagements],
          total_comments: data[:total_comments].uniq.count,
          weekly_comments: data[:sent_comments].uniq.count,
          awaiting_feedback: data[:tasks_awaiting_feedback_count],
          oldest_task_days: data[:oldest_task_days],
          total_discussions: data[:total_tasks_discussed],
          weekly_discussions: data[:weekly_tasks_discussed]
        }
      end
      rows.sort_by! { |row| [-row[:oldest_task_days].to_i, -row[:awaiting_feedback].to_i, row[:tutor_name]] }

      {
        name: stream.name,
        unallocated_students: stream_data[:num_students_without_tutors].to_i,
        tutors: rows
      }
    end
  end
  private_class_method :convenor_tutorial_streams
end
