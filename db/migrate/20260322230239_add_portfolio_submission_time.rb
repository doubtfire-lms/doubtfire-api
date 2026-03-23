class AddPortfolioSubmissionTime < ActiveRecord::Migration[8.0]
  def change
    add_column :projects, :portfolio_submission_date, :datetime
  end
end
