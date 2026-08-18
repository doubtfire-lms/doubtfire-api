class AddUnresolvedReferencesToCommunications < ActiveRecord::Migration[7.1]
  def change
    add_column :communication_conditions, :unresolved_references, :json
    add_column :communication_actions, :unresolved_references, :json
  end
end
