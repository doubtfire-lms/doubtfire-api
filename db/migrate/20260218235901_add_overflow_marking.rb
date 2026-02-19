class AddOverflowMarking < ActiveRecord::Migration[8.0]
  def change
    add_column :unit_roles, :can_mark_overflow_tasks, :boolean, default: false
  end
end
