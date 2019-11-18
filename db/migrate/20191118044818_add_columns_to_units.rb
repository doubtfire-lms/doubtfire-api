class AddColumnsToUnits < ActiveRecord::Migration
  def change
    add_column :units, :assessment_enabled, :boolean, default: true
    add_column :units, :routing_key, :string
  end
end
