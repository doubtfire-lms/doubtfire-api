class RemoveIloNumber < ActiveRecord::Migration[7.1]
  def change
    remove_column :learning_outcomes, :ilo_number, :integer
  end
end
