class Break < ActiveRecord::Base
  belongs_to :teaching_period

  validates :start_date, presence: true
  validates :number_of_weeks, presence: true
  validates :teaching_period_id, presence: true
end