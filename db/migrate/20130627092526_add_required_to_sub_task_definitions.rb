class AddRequiredToSubTaskDefinitions < ActiveRecord::Migration
  def change
    add_column :sub_task_definitions, :required, :boolean, default: false, null: false
  end
end
