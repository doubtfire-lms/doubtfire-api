class ExtendIloDescription < ActiveRecord::Migration
  def change
  	change_column :learning_outcomes, :description, :string, :limit => 2048
  end
end
