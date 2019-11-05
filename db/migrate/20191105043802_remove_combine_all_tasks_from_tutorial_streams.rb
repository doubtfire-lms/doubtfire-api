class RemoveCombineAllTasksFromTutorialStreams < ActiveRecord::Migration
  def change
    remove_column :tutorial_streams, :combine_all_tasks
  end
end
