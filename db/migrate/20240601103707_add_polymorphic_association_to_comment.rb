class AddPolymorphicAssociationToComment < ActiveRecord::Migration[7.1]
  def change
    remove_index :task_comments, :overseer_assessment_id

    add_column :task_comments, :commentable_type, :string
    rename_column :task_comments, :overseer_assessment_id, :commentable_id

    TaskComment.where('NOT commentable_id IS NULL').in_batches.update_all(commentable_type: 'OverseerAssessment')

    add_index :task_comments, [:commentable_type, :commentable_id]
  end
end
