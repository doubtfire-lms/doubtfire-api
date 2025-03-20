class CreateChipUsageAnalytics < ActiveRecord::Migration[7.1]
  def change
    create_table :chip_usage_analytics do |t|
      t.references :feedback_chip, null: false, foreign_key: true
      t.references :tutor, null: false, foreign_key: { to_table: :users }
      t.integer :usage_count, null: false, default: 0
      t.timestamps
    end
  end
end
