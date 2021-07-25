class IdCard < ActiveRecord::Base
  belongs_to :user
  has_many :check_ins
end
