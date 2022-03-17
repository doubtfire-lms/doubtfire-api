class ChangeDoNotResubmit < ActiveRecord::Migration[4.2]
  def change
    if TaskStatus.db_count > 0
      dnr = TaskStatus.feedback_exceeded
      TaskStatusComment.where(task_status: dnr).update_all(comment: 'Feedback Exceeded')
      dnr.name = 'Feedback Exceeded'
      dnr.save!
      Rails.cache.delete("task_statuses/#{dnr.id}")
    end
  end
end
