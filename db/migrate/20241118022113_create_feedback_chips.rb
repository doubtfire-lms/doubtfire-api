class CreateFeedbackChips < ActiveRecord::Migration[7.1]
  def change
    unless table_exists?(:feedback_chips)
      create_table :feedback_chips do |t|
        t.string :type
        t.text :chip_text
        t.text :description
        t.text :comment_text
        t.text :summary_text
        t.references :task_status, null: false, foreign_key: { to_table: :task_statuses }
        t.references :learning_outcome, null: false, foreign_key: { to_table: :learning_outcomes }
        t.references :parent_chip, null: true, foreign_key: { to_table: :feedback_chips }
        t.timestamps
      end
    end
  end
end
