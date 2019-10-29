class CreateTutorialStreams < ActiveRecord::Migration
  def change
    create_table :tutorial_streams do |t|
      t.string      :name,              null: false
      t.string      :abbreviation,      null: false
      t.boolean     :combine_all_tasks, null: false, :default => false
      t.timestamps                      null: false
    end
    add_reference :tutorial_streams, :activity_type, null: false, foreign_key: true
    add_index :tutorial_streams, :abbreviation
    # Partial index on combine_all_tasks when it is true, since it is mostly false
    add_index(:tutorial_streams, :combine_all_tasks, where: "combine_all_tasks")
  end
end
