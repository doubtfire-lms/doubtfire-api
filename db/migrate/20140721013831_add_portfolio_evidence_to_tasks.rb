class AddPortfolioEvidenceToTasks < ActiveRecord::Migration
  def up
    add_column :tasks, :portfolio_evidence, :string
  end
  def down
    remove_column :tasks, :portfolio_evidence
  end
end
