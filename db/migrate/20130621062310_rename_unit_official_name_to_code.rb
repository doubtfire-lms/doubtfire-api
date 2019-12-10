class RenameUnitOfficialNameToCode < ActiveRecord::Migration[4.2]
  def change
    rename_column :units, :official_name, :code
 end
end
