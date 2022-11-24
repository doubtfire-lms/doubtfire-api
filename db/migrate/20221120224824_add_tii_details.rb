class AddTiiDetails < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :tii_eula_version, :string
    add_column :units, :tii_group_context_id, :string
    add_column :task_definitions, :tii_group_id, :string
    add_column :tasks, :tii_submission_id, :string
  end
end
