class UpdateUploadRequirements < ActiveRecord::Migration[4.2]
  def change
  	change_column :task_definitions, :upload_requirements, :string, :limit => 2048
  end
end
