class CreateTeams < ActiveRecord::Migration
  def change
    create_table :teams do |t|
      t.references :project
      t.references :user
      t.string :meeting_time
      t.string :meeting_location

      t.timestamps
    end
    add_index :teams, :project_id
    add_index :teams, :user_id
  end
end
