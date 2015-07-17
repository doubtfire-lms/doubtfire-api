class CreateGroups < ActiveRecord::Migration
  def change
    create_table :groups do |t|
      t.references  :group_set
      t.references  :tutorial

      t.string      :name

      t.timestamps
    end

    create_table :group_memberships do |t|
      t.references  :group
      t.references  :project

      t.boolean     :active, default: true

      t.timestamps
    end

    create_table :group_submissions do |t|
      t.references  :group
      t.string      :notes
      t.integer     :submitted_by_project_id, index: true

      t.timestamps
    end

    add_column :task_definitions, :group_set_id, :integer, index: true

    add_column :tasks, :group_submission_id, :integer, index: true
    add_column :tasks, :contribution_pct, :integer, default: 100

    add_index :tasks, :group_submission_id
  end
end
