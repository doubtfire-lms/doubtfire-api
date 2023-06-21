class TrackPortfolioGenerationProcess < ActiveRecord::Migration[7.0]
  def change
    add_column :projects, :portfolio_generation_pid, :integer, default: nil
  end
end
