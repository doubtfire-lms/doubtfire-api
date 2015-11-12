class AddIloAbbreviation < ActiveRecord::Migration
  def change
  	add_column :learning_outcomes, :abbreviation, :string
  end
end
