class CreateBreak < ActiveRecord::Migration[4.2]
  def change
    # PostgreSQL
    execute('ALTER TABLE breaks ALTER COLUMN teaching_period_id SET DATA TYPE BIGINT')
    # MySQL
    execute('ALTER TABLE breaks MODIFY COLUMN teaching_period_id BIGINT NOT NULL AUTO_INCREMENT')

    create_table :breaks do |t|
      t.bigint          :teaching_period_id,null: false
      t.datetime        :start_date,        null: false
      t.integer         :number_of_weeks,   null: false
    end
    add_reference :breaks, :teaching_period, index: true
    add_foreign_key :breaks, :teaching_periods
  end
end
