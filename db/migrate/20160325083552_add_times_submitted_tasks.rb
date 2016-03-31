class AddTimesSubmittedTasks < ActiveRecord::Migration
  def change
    add_column :tasks, :times_submitted, :integer, :default => 0
  end
end
