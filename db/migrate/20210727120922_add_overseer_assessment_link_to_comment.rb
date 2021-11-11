class AddOverseerAssessmentLinkToComment < ActiveRecord::Migration
  def change
    # Setup a relationship between comment and overseer assessment
    add_column :task_comments, :overseer_assessment_id, :integer
    add_index :task_comments, :overseer_assessment_id
  end
end
