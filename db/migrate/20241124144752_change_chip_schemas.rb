class ChangeChipSchemas < ActiveRecord::Migration[7.1]
  def change
    # delete columns that are not needed anymore
    remove_foreign_key :feedback_chips, :feedback_chips, column: :child_chip_id

    remove_column :feedback_chips, :child_chip_id
    remove_column :feedback_chips, :title
    remove_column :feedback_chips, :order
    remove_column :feedback_chips, :abbreviation

    # rename columns to match the new schema
    rename_column :feedback_chips, :belongs_to, :related_entity
    rename_column :feedback_chips, :belongs_to_tlo, :learning_outcome

    # add new columns
    add_column :feedback_chips, :section, :string

  end
end
