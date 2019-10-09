class AddIncludeTaskInPortfolioFlag < ActiveRecord::Migration[4.2]
  def change
  	add_column :tasks, :include_in_portfolio, :boolean, :default => true
  end
end
