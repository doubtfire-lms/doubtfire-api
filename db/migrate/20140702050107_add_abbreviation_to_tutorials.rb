class AddAbbreviationToTutorials < ActiveRecord::Migration
  def change
    add_column :tutorials, :abbreviation, :string
  end
end
