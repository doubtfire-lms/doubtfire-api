class Login < ActiveRecord::Base
  belongs_to :user
  attr_accessible :user, :timestamp
end
