class Room < ActiveRecord::Base
  has_many :check_ins
  has_many :tutorials
end
