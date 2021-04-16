class ChangeDoNotResubmit < ActiveRecord::Migration
  def change
    dnr = TaskStatus.feedback_exceeded
    TaskStatusComment.where(task_status: dnr).update_all(comment: 'Feedback Exceeded')
    dnr.name = 'Feedback Exceeded'
    dnr.save!
    Rails.cache.delete("task_statuses/#{dnr.id}")
  end
end
