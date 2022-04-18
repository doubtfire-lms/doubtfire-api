class FocusCriterion < ApplicationRecord
  belongs_to :focus, optional: false

  validates :grade, uniqueness: { scope: :focus_id } # only one criteria per grade
end
