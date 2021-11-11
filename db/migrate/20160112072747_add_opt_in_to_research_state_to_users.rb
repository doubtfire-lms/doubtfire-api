class AddOptInToResearchStateToUsers < ActiveRecord::Migration[4.2]
  def up
    add_column :users, :opt_in_to_research, :boolean, default: nil
  end

  def down
    remove_column :users, :opt_in_to_research
  end
end
