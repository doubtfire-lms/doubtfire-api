class User < ActiveRecord::Base
  # Use LDAP (SIMS) for authentication
  if Rails.env.production?
    devise :ldap_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable
  else
    devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable
  end

  SystemRole::ROLES.each do |meth|
    define_method("#{meth}?") { system_role == meth }
  end

  # Devise fields
  attr_accessible :email, :remember_me
  # Model fields
  attr_accessible :first_name, :last_name, :system_role, :username, :password, :password_confirmation, :nickname, :role_ids

  # Model associations
  has_many :unit_roles, dependent: :destroy
  has_many :user_roles, dependent: :destroy
  has_many :roles, through: :user_roles
  has_many :projects, through: :unit_roles

  # Model validations/constraints
  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :username, presence: true, uniqueness: true
  validates :email, presence: true, uniqueness: true

  before_validation :generate_password, on: :create

  def self.default
    user = self.new

    user.username           = "username"
    user.first_name         = "First"
    user.last_name          = "Last"
    user.email              = "XXXXXXX@swin.edu.au"
    user.encrypted_password = BCrypt::Password.create("password")
    user.nickname           = "Nickname"
    user.system_role        = SystemRole::BASIC

    user
  end

  def email_required?
    false
  end

  def name
    "#{first_name} #{last_name}"
  end

  def generate_password
    self.password = self.password_confirmation = Devise.friendly_token.first(8)
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
        user.system_role        = role
      }

      unless user.persisted?
        user.save!(validate: false)
      end
    end
  end
end