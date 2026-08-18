class AddPortfolioDeadlineAndSubmissionLock < ActiveRecord::Migration[8.0]
  def change
    add_column :units, :lock_project_on_portfolio_submission, :boolean, default: false, null: false
    add_column :units, :portfolio_deadline_per_campus, :boolean, default: true, null: false
    add_reference :units, :portfolio_deadline_campus, null: true
  end
end
