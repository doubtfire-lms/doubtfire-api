class User < ActiveRecord::Base
  # Use LDAP (SIMS) for authentication
  if Rails.env.production?
    devise :ldap_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable
  else
    devise :database_authenticatable, :token_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable
  end

  # Model associations
  belongs_to  :role   # Foreign Key
  has_many    :unit_roles, dependent: :destroy
  has_many    :projects, through: :unit_roles

  # Model validations/constraints
  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :role_id, presence: true
  validates :username, presence: true, uniqueness: true
  validates :email, presence: true, uniqueness: true

  # Queries
  scope :teaching, -> (unit) { User.joins(:unit_roles).where("unit_roles.unit_id = :unit_id and ( unit_roles.role_id = :tutor_role_id or unit_roles.role_id = :convenor_role_id) ", unit_id: unit.id, tutor_role_id: Role.tutor_id, convenor_role_id: Role.convenor_id) }
  scope :tutors,    -> { joins(:role).where('roles.id = :tutor_role or roles.id = :convenor_role or roles.id = :admin_role', tutor_role: Role.tutor_id, convenor_role: Role.convenor_id, admin_role: Role.admin_id) }
  scope :convenors, -> { joins(:role).where('roles.id = :convenor_role or roles.id = :admin_role', convenor_role: Role.convenor_id, admin_role: Role.admin_id) }

  def username=(name)
    self[:username] = name.downcase
  end

  def has_student_capability?
    true
  end

  def has_tutor_capability?
    role_id == Role.tutor_id || has_convenor_capability?
  end

  def has_convenor_capability?
    role_id == Role.convenor_id || has_admin_capability?
  end

  def has_admin_capability?
    role_id == Role.admin_id
  end
  
  def self.permissions
    {
      # need nil for non-context permissions (can't have mixed array)
      Role.admin =>    { :promoteUser => [ Role.admin, Role.convenor, Role.tutor, Role.student ],
                         :demoteUser  => [ Role.admin, Role.convenor, Role.tutor, Role.student ],
                         :createUser  => nil,
                         :uploadCSV   => [ :tasks, :users ],
                         :downloadCSV => [ :tasks, :users ],
                         :updateUser  => nil},
      Role.convenor => { :promoteUser => [ Role.convenor, Role.tutor ],
                         :demoteUser  => [ Role.tutor ] },
                         :uploadCSV   => [ :tasks ],
                         :downloadCSV => [ :tasks ]
      Role.tutor =>    { :promoteUser => [ ],
                         :demoteUser  => [ ] },
      Role.student =>  { :promoteUser => [ ],
                         :demoteUser  => [ ] }
    }
  end

  def self.default
    user = self.new

    user.username           = "username"
    user.first_name         = "First"
    user.last_name          = "Last"
    user.email              = "XXXXXXX@swin.edu.au"
    user.nickname           = "Nickname"
    user.role_id            = Role.student_id

    user
  end


  def self.role_for(user)
    return user.role
  end

  def email_required?
    false
  end

  def name
    "#{first_name} #{last_name}"
  end

  def self.export_to_csv
    exportables = ["id", "username", "first_name", "last_name", "email", "encrypted_password", "nickname", "role_id"]
    CSV.generate do |row|
      row << User.attribute_names.select { | attribute | exportables.include? attribute }.map { | attribute | 
        # rename encrypted_password key to just password and role_id key to just role
        if attribute == "encrypted_password"
          "password"
        elsif attribute == "role_id"
          "role"
        else
          attribute
        end
      }
      User.find(:all, :order => "id").each do |user|
        row << user.attributes.select { | attribute | exportables.include? attribute }.map { | key, value |
          # pass in a blank encrypted_password and the role name instead of just role_id
          if key == "encrypted_password" 
            "" 
          elsif key == "role_id"
            Role.find(value).name
          else value end 
        }
      end
    end
  end

  def self.import_from_csv(file)
    addedUsers = []
    
    csv = CSV.read(file)
    # shift to skip header row
    csv.shift
    csv.each do |row|
      email, password, first_name, last_name, username, nickname, role = row

      user = User.find_or_create_by_username(username: username) {|user|
        user.username           = username
        user.first_name         = first_name
        user.last_name          = last_name
        user.email              = email
        user.encrypted_password = BCrypt::Password.create("password")
        user.nickname           = first_name
        user.role_id            = Role.with_name(role).id
      }
      
      unless user.persisted?
        user.save!(validate: false)
        addedUsers.push(user)
      end
    end
    
    addedUsers
  end
end