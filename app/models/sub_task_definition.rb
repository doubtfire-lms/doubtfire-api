class SubTaskDefinition < ApplicationRecord
  # Model associations
  has_many :sub_tasks, dependent: :destroy
  has_many :badges, dependent: :destroy
end
