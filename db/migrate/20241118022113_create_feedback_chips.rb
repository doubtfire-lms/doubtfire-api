class CreateFeedbackChips < ActiveRecord::Migration[7.1]
  def change
    unless table_exists?(:feedback_chips)
      create_table :feedback_chips do |t|
        t.string :type # for STI

        # template chips
        t.text :chip_text
        t.text :description
        t.text :comment_text
        t.text :summary_text
        t.string :task_status
        t.bigint :parent_chip_id
        t.bigint :learning_outcome_id

        t.timestamps
      end

      add_foreign_key :feedback_chips, :feedback_chips, column: :parent_chip_id
    end
  end
end
