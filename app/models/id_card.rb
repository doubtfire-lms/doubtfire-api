class IdCard < ApplicationRecord
  belongs_to :user
  has_many :check_ins
end
