class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :token_authenticatable, :encryptable, :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable

  # Setup accessible (or protected) attributes for your model

  # Devise fields
  attr_accessible :email, :remember_me
  # Model fields
  attr_accessible :first_name, :last_name, :system_role, :username, :encrypted_password, :nickname

  # Model associations
  has_many :team_memberships, :dependent => :destroy
  has_many :project_convenors, :dependent => :destroy   # Sounds weird - it means "may be a convenor for many projects"
  
  # Model validations/constraints
  validates_uniqueness_of :username, :email

  def superuser?
    system_role == "superuser"
  end

  def convenor?
    system_role == "convenor"
  end

  def regular_user?
    system_role == "user"
  end
  
  def name
    "#{first_name} #{last_name}"
  end

  def username_plus_name
    "#{username}-#{name}"
  end

  def self.import_from_csv(file)
    CSV.foreach(file) do |row|

      username, first_name, last_name, email, role = row

      user = User.find_or_create_by_username(:username => username) {|user|
        user.username           = username
        user.first_name         = first_name
        user.last_name          = last_name
        user.email              = email
        user.nickname           = first_name
        user.password           = "password"
        user.system_role        = role
      }

      unless user.persisted?
        user.save!
      end
    end

  end
end
