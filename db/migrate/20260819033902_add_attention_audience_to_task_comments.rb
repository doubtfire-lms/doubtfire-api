class AddAttentionAudienceToTaskComments < ActiveRecord::Migration[8.0]
  def change
    add_column :task_comments, :attention_audience, :integer
  end
end
