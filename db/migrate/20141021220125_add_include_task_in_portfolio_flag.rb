class AddIncludeTaskInPortfolioFlag < ActiveRecord::Migration
  def change
  	add_column :tasks, :include_in_portfolio, :boolean, :default => true
  end
end
