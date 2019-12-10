class ExtendIloDescription < ActiveRecord::Migration[4.2]
  def change
  	change_column :learning_outcomes, :description, :string, :limit => 2048
  end
end
