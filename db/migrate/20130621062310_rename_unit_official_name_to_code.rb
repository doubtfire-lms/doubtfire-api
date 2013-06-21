class RenameUnitOfficialNameToCode < ActiveRecord::Migration
  def change
    rename_column :units, :official_name, :code
 end
end