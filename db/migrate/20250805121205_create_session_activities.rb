class CreateSessionActivities < ActiveRecord::Migration[7.1]
  def change
    create_table :session_activities do |t|
      t.references :marking_session, null: false, foreign_key: true
      t.string :action

      t.references :project, foreign_key: true
      t.references :task, foreign_key: true
      t.references :task_definition, foreign_key: true

      t.timestamps
    end

    add_index :session_activities, [:action, :task_id, :created_at], name: "index_session_activities_on_action_task_created_at"
  end
end
