class AddIloAbbreviation < ActiveRecord::Migration[4.2]
  def change
  	add_column :learning_outcomes, :abbreviation, :string
  end
end
