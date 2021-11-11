class AddProjectCompileFlag < ActiveRecord::Migration[4.2]
  def change
  	add_column :projects, :compile_portfolio, :boolean, :default => false
  end
end
