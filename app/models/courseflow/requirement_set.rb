module Courseflow
  class RequirementSet < ApplicationRecord
    validates :requirementSetGroupId, presence: true
    validates :description, presence: true
    validates :unitId, presence: true
    validates :requirementId, presence: true
  end
end
