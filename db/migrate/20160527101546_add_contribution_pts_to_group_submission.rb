class AddContributionPtsToGroupSubmission < ActiveRecord::Migration[4.2]
  def change
    add_column :tasks, :contribution_pts, :integer, default: 3
  end
end
