# frozen_string_literal: true

class RefreshModerationFeedbackTimestampsJob
  include Sidekiq::Job

  def perform
    ModeratedTask
      .where(state: %i[open waiting_for_new_feedback])
      .includes(task: :comments)
      .find_each do |moderated_task|
      task = moderated_task.task
      next if task.nil?

      tutor_user = task.tutor
      latest_feedback_time = nil

      unless tutor_user.nil?
        sorted_comments = task.comments.sort_by(&:created_at)
        tutor_comments = sorted_comments.select.with_index do |comment, idx|
          next_comment = sorted_comments[idx + 1]

          # Automated comments after a status comment should be filtered out (Overseer test result, corrupt submission)
          # Except for when its been updated due to a prerequisite fix
          is_automated_status =
            comment.content_type == "status" &&
            next_comment&.content_type == "text" &&
            (next_comment.comment&.downcase&.include?("**automated comment**: some tests did not pass") ||
             next_comment.comment&.downcase&.include?("**automated comment**: something went wrong with your submission") ||
             next_comment.comment&.downcase&.include?("**automated comment**: a prerequisite task was updated to fix and resubmit"))

          comment.user_id == tutor_user.id &&
            %w[status discussed_in_class text].include?(comment.content_type) &&
            (comment.content_type != "status" || comment.task_status_id != TaskStatus.time_exceeded.id) &&
            !is_automated_status &&
            !comment.comment&.downcase&.include?("**automated comment**:")
        end

        latest_feedback_time = tutor_comments.max_by(&:created_at)&.created_at
      end

      next if task.last_tutor_feedback_at == latest_feedback_time

      task.update!(last_tutor_feedback_at: latest_feedback_time)
    rescue StandardError
      next
    end
  end
end
