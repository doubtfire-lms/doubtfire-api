# rubocop:disable Rails/SkipsModelValidations
class AddSubmissionHistoryToOverseerAssessments < ActiveRecord::Migration[8.0]
  class MigrationOverseerAssessment < ActiveRecord::Base
    self.table_name = 'overseer_assessments'
  end

  class MigrationSubmissionHistory < ActiveRecord::Base
    self.table_name = 'submission_histories'
  end

  def up
    add_reference :overseer_assessments, :submission_history, index: false

    MigrationOverseerAssessment.reset_column_information
    MigrationSubmissionHistory.reset_column_information

    MigrationOverseerAssessment.find_each do |assessment|
      history = MigrationSubmissionHistory.find_or_create_by!(
        task_id: assessment.task_id,
        submission_timestamp: assessment.submission_timestamp
      )
      assessment.update_columns(submission_history_id: history.id)
    end

    change_column_null :overseer_assessments, :submission_history_id, false
    add_index :overseer_assessments, :submission_history_id, unique: true
  end

  def down
    remove_reference :overseer_assessments, :submission_history
  end
end
# rubocop:enable Rails/SkipsModelValidations
