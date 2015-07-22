require 'authorisation'

class User < ActiveRecord::Base
  # attr_encrypted :email, :key => Doubtfire::Application.config.secret_attr_key, :encode => true
  attr_encrypted :auth_token, :key => Doubtfire::Application.config.secret_attr_key, :encode => true, :attribute => 'authentication_token'  

  # Use LDAP (SIMS) for authentication
  if Rails.env.production?
    devise :ldap_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable
  else
    devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable
  end

  def authenticate? (password)
    if Rails.env.production?
      self.valid_ldap_authentication?(password)
    else
      self.valid_password?(password)
    end
  end

  def extend_authentication_token (remember)
    if auth_token.nil?
      generate_authentication_token! false
      return
    end

    if remember
      if role == Role.student || role == :Student
        self.auth_token_expiry = DateTime.now + 2.weeks
      elsif role == Role.tutor || role == :Tutor
        self.auth_token_expiry = DateTime.now + 1.week
      else
        self.auth_token_expiry = DateTime.now + 2.hours
      end
    else
      self.auth_token_expiry = DateTime.now + 2.hours
    end

    self.save
  end

  def generate_authentication_token! (remember)
    token = nil

    token = loop do
      token = Devise.friendly_token
      break token unless User.find_by_auth_token(token)
    end
    self.auth_token = token

    extend_authentication_token remember

    self.save
    token
  end

  def reset_authentication_token!
    self.auth_token = nil
    self.auth_token_expiry = DateTime.now - 1.week
    self.save
  end

  # Model associations
  belongs_to  :role   # Foreign Key
  has_many    :unit_roles, dependent: :destroy
  has_many    :projects, through: :unit_roles

  # Model validations/constraints
  validates :first_name,  presence: true
  validates :last_name,   presence: true
  validates :role_id,     presence: true
  validates :username,    presence: true, :uniqueness => {:case_sensitive => false}
  validates :email,       presence: true, :uniqueness => {:case_sensitive => false}

  # Queries
  # scope :teaching, -> (unit) { User.joins(:unit_roles).where("unit_roles.unit_id = :unit_id and ( unit_roles.role_id = :tutor_role_id or unit_roles.role_id = :convenor_role_id) ", unit_id: unit.id, tutor_role_id: Role.tutor_id, convenor_role_id: Role.convenor_id) }
  scope :tutors,    -> { joins(:role).where('roles.id = :tutor_role or roles.id = :convenor_role or roles.id = :admin_role', tutor_role: Role.tutor_id, convenor_role: Role.convenor_id, admin_role: Role.admin_id) }
  scope :convenors, -> { joins(:role).where('roles.id = :convenor_role or roles.id = :admin_role', convenor_role: Role.convenor_id, admin_role: Role.admin_id) }

  def self.teaching (unit)
    User.joins(:unit_roles).where("unit_roles.unit_id = :unit_id and ( unit_roles.role_id = :tutor_role_id or unit_roles.role_id = :convenor_role_id) ", unit_id: unit.id, tutor_role_id: Role.tutor_id, convenor_role_id: Role.convenor_id)
  end

  def username=(name)
    # strip S or s from start of ids in the form S1234567 or S123456X
    if (name =~ /^[Ss]\d{6}([Xx]|\d)$/) == 0
      name[0] = ""
    end

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
  
  def self.get_change_role_perm_fn()
    lambda { |role, perm_hash, other| 
      from_role = other[0]
      to_role = other[1]

      chg_roles = perm_hash[:change_role] and 
        role_hash = chg_roles[role] and 
        from_role_hash = role_hash[from_role] and 
        from_role_hash[to_role]
    }
  end

  def self.permissions
    {
      # change role is a complex check
      change_role: { 
        #user role
        :Admin => {
          #from role  - to role
          :Admin => {     :Student  => [ :demoteUser  ],
                          :Tutor    => [ :demoteUser  ],
                          :Convenor => [ :demoteUser  ]},
          :Convenor => {  :Student  => [ :demoteUser  ],
                          :Tutor    => [ :demoteUser  ],
                          :Admin    => [ :promoteUser ]},
          :Tutor => {     :Student  => [ :demoteUser  ],
                          :Convenor => [ :promoteUser ],
                          :Admin    => [ :promoteUser ]},
          :Student => {   :Tutor    => [ :promoteUser ],
                          :Convenor => [ :promoteUser ],
                          :Admin    => [ :promoteUser ]},
          :nil => {       :Student  => [ :createUser  ],
                          :Tutor    => [ :createUser  ],
                          :Convenor => [ :createUser  ],
                          :Admin    => [ :createUser  ]}
          },
        :Convenor =>     {
          #from role  - to role
          :Tutor =>   {   :Student  => [ :demoteUser   ]},
          :Student => {   :Tutor    => [ :promoteUser  ]},
          :nil => {       :Student  => [ :createUser  ],
                          :Tutor    => [ :createUser  ]}
          }
      },

      # need nil for non-context permissions (can't have mixed array)
      :Admin =>    [ :createUser  ,
                     :uploadCSV   ,
                     :listUsers   ,
                     :downloadCSV ,
                     :updateUser  ,
                     :create_unit ,
                     :act_tutor   ,
                     :admin_units ,
                     :admin_users ,
                     :convene_units ],
      :Convenor => [ :promoteUser ,
                     :listUsers   ,
                     :createUser  ,
                     :updateUser  ,
                     :demoteUser  ,
                     :uploadCSV   ,
                     :downloadCSV ,
                     :create_unit ,
                     :act_tutor   ,
                     :convene_units ],
      :Tutor =>    [ :act_tutor ],
      :Student =>  [  ]
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

  def role_id=(new_role_id)
    new_role = Role.find(new_role_id)
    new_role = Role.student if new_role.nil?

    fail_if_in_unit_role = [ Role.tutor, Role.convenor ] if new_role == Role.student
    fail_if_in_unit_role = [ Role.convenor ] if new_role == Role.tutor
    fail_if_in_unit_role = [] if new_role == Role.admin || new_role == Role.convenor

    for check_role in fail_if_in_unit_role do
      if unit_roles.where("role_id = :role_id", role_id: check_role.id).count > 0
        return role
      end
    end

    self[:role_id] = new_role.id
  end

  #
  # Change the user's role - but ensure that it remains valid based on their roles in units
  #
  def role=(new_role)
    self.role_id = new_role.id
  end

  def email_required?
    false
  end

  def name
    fn = first_name.split(' ').first
    # fn = nickname
    sn = last_name

    if fn.length > 15
      fn = "#{fn[0..11]}..."
    end

    if sn.length > 15
      sn = "#{sn[0..11]}..."
    end

    "#{fn} #{sn}"
  end

  def self.export_to_csv
    exportables = ["username", "first_name", "last_name", "email", "nickname", "role_id"]
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

  def self.import_from_csv(current_user, file)
    addedUsers = []
    
    csv = CSV.read(file)
    # shift to skip header row
    csv.shift
    csv.each do |row|
      email, first_name, last_name, username, nickname, role = row
      # email, password, first_name, last_name, username, nickname, role = row
      
      new_role = Role.with_name(role)
      username = username.downcase    # ensure that find by username uses lowercase

      #
      # If the current user is allowed to create a user in this role
      #
      if (not new_role.nil?) && AuthorisationHelpers::authorise?(current_user, User, :createUser, User.get_change_role_perm_fn(), [ :nil, new_role.to_sym ])
        #
        # Find and update or create
        #
        user = User.find_or_create_by(username: username) {|user|
          user.first_name         = first_name.titleize
          user.last_name          = last_name.titleize
          user.email              = email
          user.encrypted_password = BCrypt::Password.create("password")
          user.nickname           = nickname.nil? || nickname.empty? ? first_name : nickname
          user.role_id            = new_role.id
        }
        
        puts "New record: #{user.new_record?}"
        puts "Persisted: #{user.persisted?}"

        # will not be persisted initially as password cannot be blank - so can check
        # which were created using this - will persist changes imported
        if user.new_record?
          user.password           = "password"
          user.save
          addedUsers.push(user) if user.persisted?
        end
      end
    end
    
    addedUsers
  end
end