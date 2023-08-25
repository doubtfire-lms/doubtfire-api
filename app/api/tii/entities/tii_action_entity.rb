module Tii
  module Entities
    class TiiActionEntity < Grape::Entity
      expose :id
      expose :type
      # expose :entity_id
      # expose :entity_type

      expose :description

      expose :complete
      expose :retries
      expose :retry
      expose :last_run
      expose :error_code
      expose :error_message
      expose :log
    end
  end
end
