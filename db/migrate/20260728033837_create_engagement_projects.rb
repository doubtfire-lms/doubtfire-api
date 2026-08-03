class CreateEngagementProjects < ActiveRecord::Migration[8.0]
  def change
    create_table :engagement_projects do |t|
      t.references :engagement, null: false, index: true
      t.references :project, null: false, index: true
      t.timestamps
    end

    add_index :engagement_projects, [:engagement_id, :project_id], unique: true
  end
end
