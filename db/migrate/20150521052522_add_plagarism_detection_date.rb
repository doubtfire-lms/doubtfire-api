class AddPlagarismDetectionDate < ActiveRecord::Migration[4.2]
  def change
  	add_column :units, :last_plagarism_scan, :datetime
  end
end
