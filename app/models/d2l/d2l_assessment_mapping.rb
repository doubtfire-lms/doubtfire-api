# frozen_string_literal: true

class D2lAssessmentMapping < ApplicationRecord
  belongs_to :unit

  # Ensure only one D2L mapping per unit
  validates :unit_id, uniqueness: true

end
