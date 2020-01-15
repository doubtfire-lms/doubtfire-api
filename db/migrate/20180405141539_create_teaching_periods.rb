class CreateTeachingPeriods < ActiveRecord::Migration[4.2]
  def change
    # PostgreSQL
    execute('ALTER TABLE teaching_periods ALTER COLUMN id SET DATA TYPE BIGINT')
    # MySQL
    execute('ALTER TABLE teaching_periods MODIFY COLUMN id BIGINT NOT NULL AUTO_INCREMENT')
   
    create_table :teaching_periods do |t|
      t.bigint          :id,              null: false
      t.string          :period,          null: false
      t.datetime        :start_date,      null: false
      t.datetime        :end_date,        null: false
    end
    add_reference :units, :teaching_period, index: true
    add_foreign_key :units, :teaching_periods
  end
end
