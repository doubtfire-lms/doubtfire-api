class UnitActivitySet < ActiveRecord::Base
  belongs_to :unit
  belongs_to :activity_type

  has_many :campus_activity_sets, dependent: :destroy
  has_many :tutorials,            dependent: :destroy

  # Always check for presence of whole model instead of id
  # So validate presence of unit not unit_id
  # This ensures that id provided is also valid, so there exists an unit with that id
  validates :activity_type, presence: true
  validates :unit,          presence: true

  validates_uniqueness_of :activity_type, :scope => :unit
end
