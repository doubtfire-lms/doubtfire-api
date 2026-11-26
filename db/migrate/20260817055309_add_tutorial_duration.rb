class AddTutorialDuration < ActiveRecord::Migration[8.0]
  def change
    add_column :tutorials, :duration_minutes, :integer, default: 120, null: false
  end
end
