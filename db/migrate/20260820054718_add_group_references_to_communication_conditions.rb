class AddGroupReferencesToCommunicationConditions < ActiveRecord::Migration[8.0]
  def change
    add_reference :communication_conditions, :group_set
    add_reference :communication_conditions, :group
  end
end
