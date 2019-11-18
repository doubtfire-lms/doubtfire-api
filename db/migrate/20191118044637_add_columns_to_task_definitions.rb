class AddColumnsToTaskDefinitions < ActiveRecord::Migration
  def change
    add_column :task_definitions, :assessment_enabled, :boolean, default: false
    add_column :task_definitions, :routing_key, :string
  end
end
