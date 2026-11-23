# Store the average wait time for feedback and the average marking time
# for each task definition in a unit.
class TaskTurnaroundReport
  Attempt = Struct.new(:task, :submitted_at, :assessments, :marking_seconds, keyword_init: true) do
    def latest_assessment
      assessments.last.assessment_time
    end

    def wait_seconds
      (latest_assessment - submitted_at).to_i
    end

    def record_review(tutor_id, opened_at, logged_at)
      return if opened_at < submitted_at || opened_at > latest_assessment

      # A status-only reopen can log 'assessing' without a corresponding assessment.
      assessment = assessments.reverse_each.find do |entry|
        entry.assessor_id == tutor_id && entry.assessment_time.between?(opened_at, logged_at)
      end
      return unless assessment

      self.marking_seconds = marking_seconds.to_i + (assessment.assessment_time - opened_at).to_i
    end
  end
  private_constant :Attempt

  def initialize(unit)
    @unit = unit
  end

  def rows
    attempts = assessed_attempts
    record_marking_times(attempts) if attempts.any?
    by_definition = attempts.group_by { |attempt| attempt.task.task_definition_id }

    @unit.task_definitions.order(:abbreviation, :id).pluck(:id, :abbreviation).map do |id, abbreviation|
      reviews = by_definition.fetch(id, [])
      marking_times = reviews.filter_map(&:marking_seconds)
      {
        task_definition_id: id, abbreviation: abbreviation,
        feedback_wait: { average_seconds: average(reviews.map(&:wait_seconds)), assessed_attempt_count: reviews.size },
        estimated_marking_time: { average_seconds: average(marking_times), measured_attempt_count: marking_times.size }
      }
    end
  end

  private

  def average(seconds)
    seconds.sum.fdiv(seconds.size).round unless seconds.empty?
  end

  def assessed_attempts
    candidates = TaskSubmission.where.not(assessment_time: nil).select(:task_id)
    tasks = Task.joins(:project).where(projects: { unit_id: @unit.id }, task_definition: @unit.task_definitions,
                                      id: candidates).preload(:project, :task_definition)
    attempts = []
    tasks.find_in_batches do |batch|
      tasks_by_id = batch.index_by(&:id)
      submissions = TaskSubmission.where(task_id: tasks_by_id.keys)
                                  .where.not(submission_time: nil).where.not(assessment_time: nil).order(:assessment_time, :id)
      evidence = student_submission_times(tasks_by_id)
      submissions.group_by { |row| [row.task_id, row.submission_time] }.each do |(task_id, submitted_at), assessments|
        task = tasks_by_id.fetch(task_id)
        first = assessments.first.assessment_time
        next if first < submitted_at
        if task.group_submission_id || task.task_definition.group_set_id || first == submitted_at
          next unless evidence.fetch(task_id, []).any? { |time| time >= submitted_at && time < first + 1.second }
        end

        attempts << Attempt.new(task: task, submitted_at: submitted_at, assessments: assessments)
      end
    end
    attempts
  end

  def student_submission_times(tasks_by_id)
    times = Hash.new { |hash, key| hash[key] = [] }
    TaskComment.where(task_id: tasks_by_id.keys, content_type: 'status', task_status_id: TaskStatus.ready_for_feedback.id)
               .pluck(:task_id, :user_id, :created_at).each do |task_id, user_id, created_at|
      times[task_id] << created_at if tasks_by_id.fetch(task_id).project.user_id == user_id
    end
    times
  end

  def record_marking_times(attempts)
    by_task = attempts.group_by { |attempt| attempt.task.id }
    by_group = attempts.select { |attempt| attempt.task.group_submission_id }
                       .group_by { |attempt| [attempt.task.group_submission_id, attempt.task.task_definition_id] }
    members = Task.where(group_submission_id: by_group.keys.map(&:first))
    members.pluck(:id, :group_submission_id, :task_definition_id).each do |task_id, group_id, definition_id|
      group_attempts = by_group[[group_id, definition_id]]
      by_task[task_id] = group_attempts if group_attempts
    end

    review_window = attempts.map(&:submitted_at).min..attempts.map(&:latest_assessment).max
    opens = SessionActivity.where(task_id: by_task.keys, action: 'get-submission-details', created_at: review_window)
    sessions = MarkingSession.where(unit_id: @unit.id, id: opens.select(:marking_session_id),
                                    start_time: ..review_window.end, end_time: review_window.begin..)
    sessions.preload(:session_activities).find_each(batch_size: 100) do |session|
      each_review_interval(session) do |task_id, opened_at, logged_at|
        by_task.fetch(task_id, []).each { |attempt| attempt.record_review(session.user_id, opened_at, logged_at) }
      end
    end
  end

  def each_review_interval(session)
    current_task = nil
    opened_at = nil
    session.session_activities.sort_by { |activity| [activity.created_at, activity.id] }.each do |activity|
      opened_at = nil if activity.task_id != current_task
      current_task = activity.task_id
      case activity.action
      when 'get-submission-details'
        opened_at ||= activity.created_at
      when 'assessing'
        yield current_task, opened_at, activity.created_at if opened_at
        opened_at = nil
      end
    end
  end
end
