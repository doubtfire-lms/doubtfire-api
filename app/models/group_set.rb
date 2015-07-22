class GroupSet < ActiveRecord::Base
  belongs_to :unit
  has_many :groups, dependent: :destroy

  validates_associated :groups
  validate :must_be_in_same_tutorial, if: :keep_groups_in_same_class

  def self.permissions
    result = { 
      :Student  => [ :get_groups ],
      :Tutor    => [ :join_group, :get_groups, :create_group ],
      :Convenor => [ :join_group, :get_groups, :create_group ],
      :nil      => [ ]
    }
  end

  def specific_permission_hash(role, perm_hash, other)
    result = perm_hash[role] unless perm_hash.nil?
    if result && role == :Student
      puts "here"
      if allow_students_to_create_groups
        result << :create_group
      end
      if allow_students_to_manage_groups
        result << :join_group
      end
    end
    result
  end

  def role_for(user)
    unit.role_for(user)
  end

  def must_be_in_same_tutorial
    if keep_groups_in_same_class
      groups.each do | grp |
        if not grp.all_members_in_tutorial?
          errors.add(:groups, "exist where some members are not in the group's tutorial")
        end
      end
    end
  end

end
