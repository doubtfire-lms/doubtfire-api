class AddAssessmentTutorialStreamLock < ActiveRecord::Migration[8.0]
  def change
    add_column :task_definitions, :lock_assessments_to_tutorial_stream, :boolean, default: false, null: false
  end
end
