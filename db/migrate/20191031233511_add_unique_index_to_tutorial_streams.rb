class AddUniqueIndexToTutorialStreams < ActiveRecord::Migration
  def change
    add_index :tutorial_streams, [:name, :unit_id], unique: true
    add_index :tutorial_streams, [:abbreviation, :unit_id], unique: true
  end
end
