class ChangeJsonToStringInDb < ActiveRecord::Migration[4.2]
  def change
  	change_column :task_definitions, :upload_requirements, :string
  end
end
