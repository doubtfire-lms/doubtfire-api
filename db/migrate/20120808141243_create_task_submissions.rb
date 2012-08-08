class CreateTaskSubmissions < ActiveRecord::Migration
  def change
    create_table :task_submissions do |t|
      t.datetime :submission_time
      t.datetime :assessment_time
      t.string :outcome
      t.references :task

      t.timestamps
    end
    add_index :task_submissions, :task_id
  end
end
