class CreateTutorialStreams < ActiveRecord::Migration
  def change
    create_table :tutorial_streams do |t|
      t.string      :name,              null: false
      t.string      :abbreviation,      null: false
      t.timestamps                      null: false
    end
    add_reference :tutorial_streams, :activity_type, null: false, foreign_key: true
    add_index :tutorial_streams, :abbreviation
  end
end
