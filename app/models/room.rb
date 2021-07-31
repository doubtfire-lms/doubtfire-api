class Room < ApplicationRecord
  has_many :check_ins
  has_many :tutorials
end
