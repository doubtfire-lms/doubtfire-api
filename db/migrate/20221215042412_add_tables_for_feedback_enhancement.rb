class AddTablesForFeedbackEnhancement < ActiveRecord::Migration[7.0]
  def change
    create_table :stages do |t|
      t.string     :title, null: false
      t.integer    :order, null: false

      t.references :task_definition
    end
  end
end
