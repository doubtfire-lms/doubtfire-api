class GroupSet < ApplicationRecord
  belongs_to :unit, optional: false
  has_many :task_definitions
  has_many :groups, dependent: :destroy

  validates :name, uniqueness: {
    scope: :unit,
    message: "should be unique within a unit"
  }
  validates :capacity, numericality: { greater_than_or_equal_to: 2 }, unless: -> { capacity.nil? }

  validates_associated :groups
  validate :must_be_in_same_tutorial, if: :keep_groups_in_same_class

  #
  # Permissions around group set data
  #
  def self.permissions
    # What can students do with group sets?
    student_role_permissions = [
      :get_groups
    ]
    # What can tutors do with group sets?
    tutor_role_permissions = [
      :get_groups,
      :join_group,
      :create_group
    ]
    # What can convenors do with group sets?
    convenor_role_permissions = [
      :get_groups,
      :join_group,
      :create_group
    ]
    # What can nil users do with group sets?
    nil_role_permissions = []

    # Return permissions hash
    {
      admin: convenor_role_permissions,
      convenor: convenor_role_permissions,
      tutor: tutor_role_permissions,
      student: student_role_permissions,
      nil: nil_role_permissions
    }
  end

  def specific_permission_hash(role, perm_hash, _other)
    result = perm_hash[role] unless perm_hash.nil?
    if result && role == :student && !locked
      result << :create_group if allow_students_to_create_groups
      result << :join_group if allow_students_to_manage_groups
    end
    result
  end

  delegate :role_for, to: :unit

  def must_be_in_same_tutorial
    if keep_groups_in_same_class
      groups.each do |grp|
        unless grp.all_members_in_tutorial?
          errors.add(:groups, "exist where some members are not in the group's tutorial")
        end
      end
    end
  end
end
