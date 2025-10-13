class AddJplagBaseCodeOption < ActiveRecord::Migration[8.0]
  def change
    add_column :task_definitions, :use_resources_for_jplag_base_code, :boolean, default: false, null: false
  end
end
