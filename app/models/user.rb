class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :token_authenticatable, :encryptable, :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable

  # Setup accessible (or protected) attributes for your model

  # Devise fields
  attr_accessible :email, :password, :password_confirmation, :remember_me
  # Model fields
  attr_accessible :first_name, :last_name, :system_role

  # Model associations
  has_many :team_memberships
  has_many :project_administrators    # Sounds weird - it means "may be an administrator for many projects"

  def is_superuser?
    @system_role == "superuser"
  end

  def is_admin?
    self.system_role == "admin"
  end

  def is_regular_user?
    self.system_role == "user"
  end
  
end
