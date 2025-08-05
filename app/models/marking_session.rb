class MarkingSession < ApplicationRecord
  belongs_to :marker, class_name: 'User'
  belongs_to :unit
  has_many :session_activities, dependent: :destroy

  validates :marker, presence: true
  validates :unit, presence: true
  validates :ip_address, presence: true
  validates :start_time, presence: true

  def update_session_details
    update(
      end_time: DateTime.now,
      duration_minutes: ((end_time - start_time) / 60).to_i
    )
  end
end
