class AddDiscussionCommentsToTaskComments < ActiveRecord::Migration[4.2]
  def change
    add_column :task_comments, :time_discussion_started, :datetime
    add_column :task_comments, :time_discussion_completed, :datetime
    add_column :task_comments, :number_of_prompts, :integer
  end
end
