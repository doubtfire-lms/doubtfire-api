class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :token_authenticatable, :encryptable, :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable

  # Setup accessible (or protected) attributes for your model

  # Devise fields
  attr_accessible :email, :password, :password_confirmation, :remember_me

  # Model fields
  attr_accessible :first_name, :last_name

  # Model associations
  has_many :team_memberships
end
