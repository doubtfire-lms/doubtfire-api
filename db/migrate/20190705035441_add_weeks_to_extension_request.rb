class AddWeeksToExtensionRequest < ActiveRecord::Migration
  def change
    add_column :task_comments, :extension_weeks, :integer
  end
end
