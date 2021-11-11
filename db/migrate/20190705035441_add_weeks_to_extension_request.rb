class AddWeeksToExtensionRequest < ActiveRecord::Migration[4.2]
  def change
    add_column :task_comments, :extension_weeks, :integer
  end
end
