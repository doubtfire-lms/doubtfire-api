# frozen_string_literal: true

class RefreshModerationFeedbackTimestampsJob
  include Sidekiq::Job

  sidekiq_options queue: 'parallel'

  BATCH_SIZE = 500
  FEEDBACK_CONTENT_TYPES = %w[status discussed_in_class text].freeze
  AUTOMATED_MARKER = '**automated comment**:'
  # Automated comments after a status comment should be filtered out (Overseer test result, corrupt submission)
  # Except for when its been updated due to a prerequisite fix
  AUTOMATED_STATUS_FOLLOW_UPS = [
    '**automated comment**: some tests did not pass',
    '**automated comment**: something went wrong with your submission',
    '**automated comment**: a prerequisite task was updated to fix and resubmit'
  ].freeze

  def perform
    time_exceeded_id = TaskStatus.time_exceeded.id

    ModeratedTask
      .where(state: %i[open waiting_for_new_feedback])
      .joins(task: { project: :unit })
      .where(units: { id: Unit.within_teaching_dates.select(:id) })
      .in_batches(of: BATCH_SIZE) do |batch|
        task_ids = batch.pluck(:task_id).uniq
        tasks = Task
                .where(id: task_ids)
                .select(:id, :project_id, :task_definition_id, :last_tutor_feedback_at)
                .includes(:task_definition, project: [{ unit: :main_convenor }, { tutorial_enrolments: { tutorial: :unit_role } }])
        comments_by_task = load_comments(task_ids)

        tasks.each do |task|
          tutor_id = tutor_id_for(task)
          latest_feedback_time = tutor_id && latest_feedback_time(comments_by_task[task.id] || [], tutor_id, time_exceeded_id)
          next if task.last_tutor_feedback_at == latest_feedback_time

          # Derived cache column; Task validations add queries and can block the refresh
          task.update_column(:last_tutor_feedback_at, latest_feedback_time) # rubocop:disable Rails/SkipsModelValidations
        rescue StandardError => e
          Rails.logger.error("RefreshModerationFeedbackTimestampsJob failed for task #{task.id}: #{e.message}")
        end
      end
  end

  private

  def load_comments(task_ids)
    TaskComment
      .where(task_id: task_ids)
      .order(:task_id, :created_at, :id)
      .pluck(:task_id, :user_id, :content_type, :task_status_id, :created_at, :comment)
      .group_by(&:first)
  end

  # In-memory equivalent of Project#tutor_for, using the preloaded associations
  def tutor_id_for(task)
    project = task.project
    task_definition = task.task_definition
    unless task_definition.nil?
      stream_id = task_definition.tutorial_stream_id
      enrolment = project.tutorial_enrolments
                         .select { |e| e.tutorial.tutorial_stream_id.nil? || e.tutorial.tutorial_stream_id == stream_id }
                         .min_by(&:id)
      tutor_id = enrolment&.tutorial&.unit_role&.user_id
      return tutor_id if tutor_id.present?
    end

    project.unit.main_convenor&.user_id
  end

  # comments are sorted by created_at ascending
  def latest_feedback_time(comments, tutor_id, time_exceeded_id)
    (comments.length - 1).downto(0) do |idx|
      _, user_id, content_type, task_status_id, created_at, text = comments[idx]
      next unless user_id == tutor_id && FEEDBACK_CONTENT_TYPES.include?(content_type)
      next if text&.downcase&.include?(AUTOMATED_MARKER)

      if content_type == 'status'
        next if task_status_id == time_exceeded_id

        _, _, next_type, _, _, next_text = comments[idx + 1]
        next_text = next_text&.downcase
        next if next_type == 'text' && next_text && AUTOMATED_STATUS_FOLLOW_UPS.any? { |m| next_text.include?(m) }
      end

      return created_at
    end

    nil
  end
end
