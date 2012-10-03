class RemoveProjectStatuses < ActiveRecord::Migration
  def up
    drop_table :project_statuses
    remove_column :projects, :project_status_id
  end

  def down
    create_table :project_statuses do |t|
      t.decimal :health

      t.timestamps
    end
  end
end