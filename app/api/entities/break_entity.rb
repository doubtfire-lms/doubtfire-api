module Api
  module Entities
    class BreakEntity < Grape::Entity
      expose :id
      expose :start_date
      expose :number_of_weeks
    end
  end
end
