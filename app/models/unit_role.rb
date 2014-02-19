class UnitRole < ActiveRecord::Base
  default_scope include: :role

  # Model associations
  belongs_to :unit    # Foreign key
  belongs_to :user		# Foreign key
  belongs_to :tutorial 		# Foreign key
  belongs_to :role    # Foreign key
  has_one :project, dependent: :destroy

  attr_accessible :unit_id, :user_id, :tutorial_id, :role_id

  validates :unit_id, presence: true
  validates :user_id, presence: true
  validates :role_id, presence: true

  scope :students,  -> { where('role_id = ?', 1) }
  scope :staff,     -> { where('role_id != ?', 1) }
end