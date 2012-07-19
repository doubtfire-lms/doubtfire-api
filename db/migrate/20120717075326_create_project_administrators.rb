class CreateProjectAdministrators < ActiveRecord::Migration
  def change
    create_table :project_administrators do |t|
    	t.references :project_template
    	t.references :user

	    t.timestamps
    end
  end
end
