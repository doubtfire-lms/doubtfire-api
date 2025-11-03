class AddAssessorToProjects < ActiveRecord::Migration[8.0]
  def change
    add_reference :projects, :assessor, null: true
  end
end
