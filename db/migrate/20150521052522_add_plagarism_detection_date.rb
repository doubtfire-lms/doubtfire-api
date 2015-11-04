class AddPlagarismDetectionDate < ActiveRecord::Migration
  def change
  	add_column :units, :last_plagarism_scan, :datetime
  end
end
