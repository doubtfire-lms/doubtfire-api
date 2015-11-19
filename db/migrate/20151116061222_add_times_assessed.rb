class AddTimesAssessed < ActiveRecord::Migration
  def change
  	add_column :tasks, :times_assessed, :integer, default: 0
  	add_column :tasks, :submission_date, :datetime
  	add_column :tasks, :assessment_date, :datetime

  	remove_column :tasks, :awaiting_signoff
  end
end
