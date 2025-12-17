class OverseerStep < ApplicationRecord
  belongs_to :task_definition, optional: false

end
