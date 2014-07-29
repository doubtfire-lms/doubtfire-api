class ChangeJsonToStringInDb < ActiveRecord::Migration
  def change
  	change_column :task_definitions, :upload_requirements, :string
  end
end
