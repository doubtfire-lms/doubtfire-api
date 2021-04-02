class AdjustChangeTutorialPermissions < ActiveRecord::Migration
  def change
    add_column :units, :allow_student_change_tutorial, :boolean, null: false, default: true
  end
end
