class UnitRole < ActiveRecord::Base

  # Model associations
  belongs_to :unit    # Foreign key
  belongs_to :user		# Foreign key
  belongs_to :tutorial 		# Foreign key
  belongs_to :role    # Foreign key
  has_one :project, dependent: :destroy

  validates :unit_id, presence: true
  validates :user_id, presence: true
  validates :role_id, presence: true

  scope :students,  -> { where('role_id = ?', 1) }
  scope :staff,     -> { where('role_id != ?', 1) }
end
