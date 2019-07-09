class AddDiscussionCommentsToTaskComments < ActiveRecord::Migration
  def change
    add_column :task_comments, :time_discussion_started, :datetime
    add_column :task_comments, :time_discussion_completed, :datetime
    add_column :task_comments, :number_of_prompts, :integer
  end
end
