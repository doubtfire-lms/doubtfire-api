class CreateTaskTemplates < ActiveRecord::Migration
  def change
    create_table :task_templates do |t|
      t.references :project_template
      t.string :name
      t.string :description
      t.decimal :weighting
      t.boolean :required
      t.datetime :recommended_completion_date

      t.timestamps
    end
    add_index :task_templates, :project_template_id
  end
end
