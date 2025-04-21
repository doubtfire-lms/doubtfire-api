class AddCurrentOrganizationIdToUsers < ActiveRecord::Migration[7.1]
  def change
    add_reference :users, :current_organization, foreign_key: { to_table: :organizations }
  end
end
