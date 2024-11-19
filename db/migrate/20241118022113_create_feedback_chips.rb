class CreateFeedbackChips < ActiveRecord::Migration[7.1]
  def change
    unless table_exists?(:feedback_chips)
      create_table :feedback_chips do |t|
        t.string :type # for STI

        # template chips
        t.string :abbreviation
        t.integer :order
        t.text :chip_text
        t.text :description
        t.text :comment_text
        t.text :summary_text
        t.string :task_status

        # group chips
        t.string :title
        t.integer :parent_chip_id
        t.integer :child_chip_id
        t.string :belongs_to
        t.string :belongs_to_tlo

        t.timestamps
      end

      add_foreign_key :feedback_chips, :feedback_chips, column: :parent_chip_id
      add_foreign_key :feedback_chips, :feedback_chips, column: :child_chip_id
    end
  end
end
