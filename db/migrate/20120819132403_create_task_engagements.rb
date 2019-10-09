class CreateTaskEngagements < ActiveRecord::Migration[4.2]
  def change
    create_table :task_engagements do |t|
      t.datetime :engagement_time
      t.string :engagement
      t.references :task

      t.timestamps
    end
    add_index :task_engagements, :task_id
  end
end
