class CreateTeams < ActiveRecord::Migration
  def change
    create_table :teams do |t|
      t.references :project_template
      t.references :user
      t.string :meeting_day
      t.string :meeting_time
      t.string :meeting_location

      t.timestamps
    end
    add_index :teams, :project_template_id
    add_index :teams, :user_id
  end
end
