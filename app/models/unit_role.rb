class UnitRole < ActiveRecord::Base

  # Model associations
  belongs_to :unit    # Foreign key
  belongs_to :user    # Foreign key
  
  belongs_to :role    # Foreign key

  belongs_to :tutorial  # for students only! TODO: fix
  has_one  :project, dependent: :destroy, inverse_of: :unit_role # for students only! TODO: fix

  has_many :taught_tutorials, class_name: "Tutorial", dependent: :nullify

  validates :unit_id, presence: true
  validates :user_id, presence: true
  validates :role_id, presence: true
  validate :must_be_in_group_tutorials


  scope :students,  -> { joins(:role).where('roles.name = :role', role: 'Student') }
  scope :tutors,    -> { joins(:role).where('roles.name = :role', role: 'Tutor') }
  scope :convenors, -> { joins(:role).where('roles.name = :role', role: 'Convenor') }
  # scope :staff,     -> { where('role_id != ?', 1) }

  def self.for_user(user)
    UnitRole.joins(:role, :unit).where("user_id = :user_id and roles.name <> 'Student'", user_id: user.id)
  end

  # unit roles are now unique for users in units
  # TODO: check this usage
  def other_roles
    []
  end

  def self.permissions
    { 
      :Student => [ :get ],
      :Convenor => [ :get, :getProjects, :delete ],
      :Tutor => [ :get, :getProjects ],
      :nil => [ ]
    }
  end

  #
  # Check to see if the student has a valid tutorial
  #
  def must_be_in_group_tutorials
    return unless project
    project.groups.each { |g| 
      if g.limit_members_to_tutorial?
        if tutorial != g.tutorial
          if g.group_set.allow_students_to_manage_groups
            # leave group
            g.remove_member(project)
          else
            errors.add(:groups, "require you to be in tutorial #{g.tutorial.abbreviation}")
            break
          end
        end
      end
    }
  end

  def self.tasks_to_review(user)    
    ready_to_mark = []
    
    # There has be a better way to do this surely...
    tutorials = Tutorial.find_by_user(user)
    tutorials.each do | tutorial |
      tutorial.projects.each do | project |
        project.tasks.each do | task | 
          ready_to_mark << task if task.has_pdf && ( task.ready_to_mark? || task.need_help?)
        end
      end
    end
       
    ready_to_mark
  end

  def role_for(user)
    unit_role = unit.role_for(user)
    if unit_role == Role.student && self.user != user
      unit_role = nil
    end
    unit_role
  end  

  def is_tutor?
    role == Role.tutor
  end

  def is_student?
    role == Role.student
  end

  def is_convenor?
    role == Role.convenor
  end

  def is_teacher?
    is_tutor? || is_convenor?
  end
end
