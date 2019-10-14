class AddUnitActivitySetToTutorials < ActiveRecord::Migration
  def change
    add_reference :tutorials, :unit_activity_set, foreign_key: true, index: true
  end
end
