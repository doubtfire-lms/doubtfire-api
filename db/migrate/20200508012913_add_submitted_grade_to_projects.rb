class AddSubmittedGradeToProjects < ActiveRecord::Migration
  def change
    add_column :projects, :submitted_grade, :integer
  end
end
