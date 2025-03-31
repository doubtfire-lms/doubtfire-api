module Courseflow
  class Specialization < ApplicationRecord
    validates :specialization, presence: true
  end
end
