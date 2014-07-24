class AddUploadRequirementsToTaskDefinitions < ActiveRecord::Migration
  def up
    add_column :task_definitions, :upload_requirements, :json
  end
  def down
    remove_column :task_definitions, :upload_requirements
  end
end
