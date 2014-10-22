class AddProjectCompileFlag < ActiveRecord::Migration
  def change
  	add_column :projects, :compile_portfolio, :boolean, :default => false
  end
end
