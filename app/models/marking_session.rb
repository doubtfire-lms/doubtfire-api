class MarkingSession < ApplicationRecord
  belongs_to :user
  belongs_to :unit
  has_many :session_activities, dependent: :destroy

  validates :user, presence: true
  validates :unit, presence: true
  validates :ip_address, presence: true
  validates :start_time, presence: true

  def duration_minutes
    return 0 unless start_time && end_time
    ((end_time - start_time) / 60).to_i
  end

  def update_session_details
    now = DateTime.now
    update(end_time: now)
  end
end
