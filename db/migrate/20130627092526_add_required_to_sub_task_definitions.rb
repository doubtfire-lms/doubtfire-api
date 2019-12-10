class AddRequiredToSubTaskDefinitions < ActiveRecord::Migration[4.2]
  def change
    add_column :sub_task_definitions, :required, :boolean, default: false, null: false
  end
end
