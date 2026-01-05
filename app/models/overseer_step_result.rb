class OverseerStepResult < ApplicationRecord
  belongs_to :overseer_assessment, optional: false
  belongs_to :overseer_step, optional: false

end
