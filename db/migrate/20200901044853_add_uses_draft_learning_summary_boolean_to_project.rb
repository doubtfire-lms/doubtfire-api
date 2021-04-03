class AddUsesDraftLearningSummaryBooleanToProject < ActiveRecord::Migration
  def change
    add_column :projects, :uses_draft_learning_summary, :boolean, default: false, null: false
  end
end
