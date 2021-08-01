class CheckIn < ApplicationRecord
  belongs_to :room
  belongs_to :id_card

  scope :only_active, -> { where(checkout_at: nil).or(where(CheckIn.arel_table[:checkout_at].gt(Time.zone.now))) }
end