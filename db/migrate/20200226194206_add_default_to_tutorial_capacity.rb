class AddDefaultToTutorialCapacity < ActiveRecord::Migration
  def change
    Tutorial.where(capacity: nil).update_all(capacity: -1)
    change_column :tutorials, :capacity, :integer, default: -1
  end
end
