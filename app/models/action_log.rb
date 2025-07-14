class ActionLog < ApplicationRecord

  belongs_to :user
  serialize :properties, coder: JSON
end
