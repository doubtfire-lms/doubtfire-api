class TeachingPeriod < ActiveRecord::Base
  has_many :units
  
  validates :period, length: { minimum: 1, maximum: 10, allow_blank: false }  
  validates :start_date, presence: true
  validates :end_date, presence: true
end
