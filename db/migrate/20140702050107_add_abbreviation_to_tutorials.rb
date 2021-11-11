class AddAbbreviationToTutorials < ActiveRecord::Migration[4.2]
  def change
    add_column :tutorials, :abbreviation, :string
  end
end
