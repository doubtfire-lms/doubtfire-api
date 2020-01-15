class CreateBreak < ActiveRecord::Migration[4.2]
  def change
    create_table :breaks, teaching_period_id: :integer do |t|
      t.datetime        :start_date,        null: false
      t.integer         :number_of_weeks,   null: false
    end
    add_reference :breaks, :teaching_period, index: true
    add_foreign_key :breaks, :teaching_periods
  end
end
