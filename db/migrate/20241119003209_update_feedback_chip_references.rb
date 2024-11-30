class UpdateFeedbackChipReferences < ActiveRecord::Migration[7.1]
  def change
    change_column :feedback_chips, :parent_chip_id, :bigint, null: true
  end
end
