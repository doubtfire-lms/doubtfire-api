class AddMentorToUnitRole < ActiveRecord::Migration[8.0]
  def change
    add_reference :unit_roles, :mentor, index: true
  end
end
