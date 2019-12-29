class RemoveTutorialFromProjects < ActiveRecord::Migration
  def change
    remove_column :projects, :tutorial_id
  end
end
