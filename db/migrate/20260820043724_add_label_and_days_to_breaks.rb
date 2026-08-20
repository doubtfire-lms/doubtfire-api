class AddLabelAndDaysToBreaks < ActiveRecord::Migration[8.0]
  def up
    add_column :breaks, :label, :string
    add_column :breaks, :number_of_days, :integer

    execute 'UPDATE breaks SET number_of_days = number_of_weeks * 7'

    change_column_null :breaks, :number_of_days, false
    remove_column :breaks, :number_of_weeks
  end

  def down
    add_column :breaks, :number_of_weeks, :integer

    execute 'UPDATE breaks SET number_of_weeks = CEIL(number_of_days / 7)'

    change_column_null :breaks, :number_of_weeks, false
    remove_column :breaks, :number_of_days
    remove_column :breaks, :label
  end
end
