class CreateProjectConvenors < ActiveRecord::Migration[4.2]
  def change
    create_table :project_convenors do |t|
    	t.references :project_template
    	t.references :user

	    t.timestamps
    end
  end
end
