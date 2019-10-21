class CampusActivitySet < ActiveRecord::Base
  belongs_to :campus
  belongs_to :unit_activity_set

  validates :campus,            presence: true
  validates :unit_activity_set, presence: true

  validates_uniqueness_of :unit_activity_set, :scope => :campus, message: 'already exists for the selected campus'
end
