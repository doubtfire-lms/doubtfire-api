class AddAssessorToProjects < ActiveRecord::Migration[8.0]
  def change
    add_reference :projects, :assessor, index: true, null: true
  end
end
