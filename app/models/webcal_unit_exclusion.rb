class WebcalUnitExclusion < ActiveRecord::Base
  belongs_to :webcal
  belongs_to :unit
end
