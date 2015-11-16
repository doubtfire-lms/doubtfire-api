class AddTimesAssessed < ActiveRecord::Migration
  def change
  	add_column :tasks, :times_assessed, :integer, default: 0
  end
end
