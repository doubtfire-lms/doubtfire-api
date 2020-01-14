class AddAbbreviationToCampuses < ActiveRecord::Migration
  def change
    add_column :campuses, :abbreviation, :string, null: false
  end
end
