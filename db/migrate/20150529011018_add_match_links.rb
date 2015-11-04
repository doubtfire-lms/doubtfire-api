class AddMatchLinks < ActiveRecord::Migration
  def change
  	create_table :plagiarism_match_links do |t|
      t.belongs_to :task, index: true
      t.belongs_to :other_task, index: true

      t.integer :pct

      t.timestamps
    end
  end
end
