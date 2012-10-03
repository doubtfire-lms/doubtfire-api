class CreateProjectStatuses < ActiveRecord::Migration
  def change
    create_table :project_statuses do |t|
      t.decimal :health

      t.timestamps
    end
  end
end