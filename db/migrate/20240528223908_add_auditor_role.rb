class AddAuditorRole < ActiveRecord::Migration[7.0]
  # Add the auditor role
  def up
    return if Role.where(name: 'Auditor').first.present?

    Role.create(
      name: 'Auditor',
      description: 'Auditors are able to view only everything an admin can.'
    )
  end

  # Remove the auditor role
  def down
    auditor_role = Role.where(name: 'Auditor').first
    return unless auditor_role.present?

    auditor_role.destroy
  end
end
