class CreateProjectTemplates < ActiveRecord::Migration[4.2]
  def change
    create_table :project_templates do |t|
      t.string :name
      t.string :description
      t.datetime :start_date
      t.datetime :end_date

      t.timestamps
    end
  end
end
