class AddUnitToTutorialStreams < ActiveRecord::Migration
  def change
    add_reference :tutorial_streams, :unit, null: false, foreign_key: true, index: true
  end
end
