class GroupSet < ActiveRecord::Base
  belongs_to :unit
  has_many :groups, dependent: :destroy

  def self.permissions
    result = { 
      :Student  => [ :get_groups ],
      :Tutor    => [ :get_groups, :create_group, :manage_group ],
      :Convenor => [ :get_groups, :create_group, :manage_group ],
      :nil      => [ ]
    }
  end

  def specific_permission_hash(role, perm_hash, other)
    result = perm_hash[role] unless perm_hash.nil?
    if result && role == :Student
      if allow_students_to_create_groups
        result << :create_group
      end
    end
    result
  end

  def role_for(user)
    unit.role_for(user)
  end

end
