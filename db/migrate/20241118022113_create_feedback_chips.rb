class CreateFeedbackChips < ActiveRecord::Migration[7.1]
  def change
    unless table_exists?(:feedback_chips)
      create_table :feedback_chips do |t|
        t.string :type
        t.text :chip_text
        t.text :description
        t.text :comment_text
        t.text :summary_text
        t.references :task_statuses, null: false, foreign_key: true
        t.references :learning_outcomes, null: false, foreign_key: true
        t.references :parent_chip, null: true, foreign_key: { to_table: :feedback_chips }
        t.timestamps
      end
    end
  end
end
