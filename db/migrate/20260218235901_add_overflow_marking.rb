class AddOverflowMarking < ActiveRecord::Migration[8.0]
  def change
    add_column :unit_roles, :can_mark_overflow_tasks, :boolean, default: false

    add_column :units, :feedback_warning_threshold_days, :integer, default: 5
    add_column :units, :feedback_overflow_threshold_days, :integer, default: 7
  end
end
