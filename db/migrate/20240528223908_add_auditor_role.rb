class AddAuditorRole < ActiveRecord::Migration[7.0]
  # Add the auditor role
  def up
    return if Role.where(name: 'Auditor').first.present?
    return if Role.where(id: 5).first.present?

    role = Role.create(
      name: 'Auditor',
      description: 'Auditors are able to view units but not change details.'
    )

    role.id = 5
    role.save
  end

  # Remove the auditor role
  def down
    auditor_role = Role.where(id: 5).first
    return unless auditor_role.present?

    auditor_role.destroy
  end
end
