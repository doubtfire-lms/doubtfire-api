class CreateProjectAdministrators < ActiveRecord::Migration
  def change
    create_table :project_administrators do |t|
    	t.references :project
    	t.references :user

	    t.timestamps
    end
  end
end
