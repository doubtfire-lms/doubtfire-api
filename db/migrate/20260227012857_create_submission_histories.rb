class CreateSubmissionHistories < ActiveRecord::Migration[8.0]
  def change
    create_table :submission_histories do |t|
      t.references :task
      t.integer :submission_timestamp
      t.timestamps
    end
  end
end
