class AddArchiveUnitFlag < ActiveRecord::Migration[7.1]
  def change
    add_column :units, :archived, :boolean, default: false
  end
end
