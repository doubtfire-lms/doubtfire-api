# frozen_string_literal: true

class TaskCompletionSnapshot < ApplicationRecord
  belongs_to :unit
  
  attribute :stats, :json

  validates :snapshot_date, :captured_at, :stats, presence: true
  validates :snapshot_date, uniqueness: { scope: :unit_id }
end
