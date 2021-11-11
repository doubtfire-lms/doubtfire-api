class UpdateExistingAssessmentComments < ActiveRecord::Migration
  def change
    # Make sure existing assessment comments use new class
    TaskComment.where(content_type: 'assessment').each do |tc|
      tc.update(overseer_assessment_id: tc.task.overseer_assessments.last.id, type: 'AssessmentComment')
    end
  end
end
