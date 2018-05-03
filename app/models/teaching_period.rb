class TeachingPeriod < ActiveRecord::Base
  has_many :units
  
  validates :period, length: { minimum: 1, maximum: 20, allow_blank: false }, uniqueness: true  
  validates :start_date, presence: true
  validates :end_date, presence: true
end
