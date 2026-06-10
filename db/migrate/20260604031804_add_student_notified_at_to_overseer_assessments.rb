class AddStudentNotifiedAtToOverseerAssessments < ActiveRecord::Migration[8.0]
  def change
    add_column :overseer_assessments, :student_notified_at, :datetime
    add_index :overseer_assessments, [:status, :student_notified_at, :updated_at],
              name: 'index_overseer_assessments_on_status_notified_updated'
  end
end
