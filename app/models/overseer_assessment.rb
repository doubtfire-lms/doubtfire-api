class OverseerAssessment < ActiveRecord::Base
  belongs_to :task

  validates :status,                  presence: true
  validates :task_id,                 presence: true
  validates :submission_timestamp,    presence: true

  validates_uniqueness_of :submission_timestamp, scope: :task_id

  enum mode: { not_queued: 0, queued: 1, queue_failed: 2, done: 3 }
end
