class CreateSessionActivities < ActiveRecord::Migration[7.1]
  def change
    create_table :session_activities do |t|
      t.references :marking_session, null: false
      t.string :action

      t.references :project
      t.references :task
      t.references :task_definition

      t.timestamps
    end

    add_index :session_activities, [:action, :task_id, :created_at], name: "index_session_activities_on_action_task_created_at"
  end
end
