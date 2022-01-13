class WebcalUnitExclusion < ApplicationRecord
  belongs_to :webcal, optional: false
  belongs_to :unit, optional: false
end
