class UnitAddMainConvenor < ActiveRecord::Migration
  def change
    add_reference :units, :main_convenor, references: :unit_roles

    Unit.all.each do |u|
      u.update(main_convenor_id: u.convenors.first.id)
    end
  end
end
