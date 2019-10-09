class AddPortfolioEvidenceToTasks < ActiveRecord::Migration[4.2]
  def up
    add_column :tasks, :portfolio_evidence, :string
  end
  def down
    remove_column :tasks, :portfolio_evidence
  end
end
