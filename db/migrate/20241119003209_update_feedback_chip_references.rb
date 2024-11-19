class UpdateFeedbackChipReferences < ActiveRecord::Migration[7.1]
  def change
    change_column :feedback_chips, :parent_chip_id, :bigint, null: true
    change_column :feedback_chips, :child_chip_id, :bigint, null: true

    add_foreign_key :feedback_chips, :feedback_chips, column: :parent_chip_id
    add_foreign_key :feedback_chips, :feedback_chips, column: :child_chip_id
  end
end
