class AddPolymorphicAssociationToComment < ActiveRecord::Migration[7.1]
  def change
    remove_index :task_comments, :overseer_assessment_id

    add_column :task_comments, :commentable_type, :string
    rename_column :task_comments, :overseer_assessment_id, :commentable_id

    TaskComment.find_each do |comment|
      if comment.commentable_id.present?
        comment.update(commentable_type: 'OverseerAssessment')
      end
    end

    add_index :task_comments, [:commentable_type, :commentable_id]
  end
end
