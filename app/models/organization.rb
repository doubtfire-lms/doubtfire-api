class Organization < ApplicationRecord
  has_many :user_organizations, dependent: :destroy  
  has_many :users, through: :user_organizations
    
  validates :name, presence: true, uniqueness: { case_sensitive: false }
    
  scope :enabled, -> { where(is_enabled: true) }
    
  def to_s
    name
  end

  def self.permissions 
    # what can admins do with organizations?
    admin_role_permissions = [
      :manage_organization,
      :manage_members,
      :view_members,
      :view_enrolled_organizations
    ]

    # what can members do with organizations?
    convenor_role_permissions = [
      :view_members,
      :manage_members,
      :view_enrolled_organizations
    ]

    # what can tutors do with organizations?
    tutor_role_permissions = [
      :view_members,
      :view_enrolled_organizations
    ]

    # what can auditors do with organizations?
    auditor_role_permissions = [
      :view_members,
      :view_enrolled_organizations
    ]

    # what can students do with organizations?
    students_role_permissions = [
      :view_enrolled_organizations
    ]
    
    # Return permissions hash
    {
      admin: admin_role_permissions,
      convenor: convenor_role_permissions,
      tutor: tutor_role_permissions,
      auditor: auditor_role_permissions,
      student: students_role_permissions
    }
  end
  
  def role_for(user)
    # If user belongs to a specific organization, they get role
    if users.include?(user)
      user.role
    else
      nil
    end
  end
end