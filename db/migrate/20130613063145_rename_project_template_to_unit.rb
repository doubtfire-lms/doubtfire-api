class RenameUnitToUnit < ActiveRecord::Migration
  def change
    rename_table :units, :units
  end
end
