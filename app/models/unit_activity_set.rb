class UnitActivitySet < ActiveRecord::Base
  belongs_to :unit

  validates :activity_type, presence: true
  validates :unit_id, presence: true
end
