class AddContributionPtsToGroupSubmission < ActiveRecord::Migration
  def change
    add_column :tasks, :contribution_pts, :integer, default: 3
  end
end
