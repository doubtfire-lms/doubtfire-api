class AddLastTutorFeedbackAtToTasks < ActiveRecord::Migration[8.0]
  def change
    add_column :tasks, :last_tutor_feedback_at, :datetime
  end
end
