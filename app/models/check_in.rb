class CheckIn < ApplicationRecord
  belongs_to :room
  belongs_to :id_card

  scope :only_active, -> { where(checkout_at: nil) }
end
