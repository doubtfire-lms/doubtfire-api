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

  def email_required?
    false
  end

  def name
    "#{first_name} #{last_name}"
  end

  def self.import_from_csv(file)
    CSV.foreach(file) do |row|

      username, first_name, last_name, email, role = row

      user = User.find_or_create_by_username(username: username) {|user|
        user.username           = username
        user.first_name         = first_name
        user.last_name          = last_name
        user.email              = email
        user.encrypted_password = BCrypt::Password.create("password")
        user.nickname           = first_name
        user.role_id            = role
      }

      unless user.persisted?
        user.save!(validate: false)
      end
    end
  end
end