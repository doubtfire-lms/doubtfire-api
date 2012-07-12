class CreateTasks < ActiveRecord::Migration
  def change
    create_table :tasks do |t|
      t.references :project
      t.string :name
      t.string :description
      t.decimal :weighting
      t.boolean :required
      t.datetime :recommended_completion_date

      t.timestamps
    end
    add_index :tasks, :project_id
  end
end
