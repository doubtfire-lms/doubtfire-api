class UnitRole < ActiveRecord::Base
  # Model associations
  belongs_to :unit    # Foreign key
  belongs_to :user		# Foreign key
  belongs_to :tutorial 		# Foreign key
  has_one :role    # Foreign key
  has_one :project, dependent: :destroy

  attr_accessible :unit_id, :user_id, :tutorial_id, :role_id

  scope :students,  -> { where('role_id = ?', 1) }
  scope :staff,     -> { where('role_id != ?', 1) }
end