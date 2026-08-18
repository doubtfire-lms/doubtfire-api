class AddPortfolioDeadlineAndSubmissionLock < ActiveRecord::Migration[8.0]
  def change
    add_column :units, :lock_project_on_portfolio_submission, :boolean, default: false, null: false
  end
end
