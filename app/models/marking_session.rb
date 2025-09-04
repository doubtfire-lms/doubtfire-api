class MarkingSession < ApplicationRecord
  belongs_to :marker, class_name: 'User'
  belongs_to :unit
  has_many :session_activities, dependent: :destroy

  validates :marker, presence: true
  validates :unit, presence: true
  validates :ip_address, presence: true
  validates :start_time, presence: true

  def update_session_details
    now = DateTime.now
    if start_time.present?
      duration = ((now.to_f - start_time.to_f) / 60).to_i
      update(
        end_time: now,
        duration_minutes: duration
      )
    else
      update(end_time: now, duration_minutes: 0)
    end
  end
end
