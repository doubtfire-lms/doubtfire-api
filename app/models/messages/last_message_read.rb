class LastMessageRead < ApplicationRecord
  # todo: validations
  belongs_to :user, optional: false
  belongs_to :message, optional: false


  # datetime:read_at
  # bigint:context_id
  # enum:context_type (0 is task)

  enum context_type: { task: 0, project: 1, unit: 2, system: 3 }
end
