class CreateTeachingPeriods < ActiveRecord::Migration[4.2]
  def change
    create_table :teaching_periods, id: :integer do |t|
      t.string          :period,          null: false
      t.datetime        :start_date,      null: false
      t.datetime        :end_date,        null: false
    end
    add_reference :units, :teaching_period, index: true
    add_foreign_key :units, :teaching_periods
  end
end
