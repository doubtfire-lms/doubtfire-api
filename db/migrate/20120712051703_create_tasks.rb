class CreateTasks < ActiveRecord::Migration
  def change
    create_table :tasks do |t|
      t.references :task_template
      t.references :project
      t.references :task_status
      t.boolean :awaiting_signoff

      t.timestamps
    end
    add_index :tasks, :task_template_id
    add_index :tasks, :project_id
    add_index :tasks, :task_status_id
  end
end
