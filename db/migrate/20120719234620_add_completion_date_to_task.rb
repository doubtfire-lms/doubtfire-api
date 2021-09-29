class AddCompletionDateToTask < ActiveRecord::Migration[4.2]
  def change
    add_column :tasks, :completion_date, :date
  end
end
