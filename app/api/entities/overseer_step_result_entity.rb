module Entities
  class OverseerStepResultEntity < Grape::Entity
    expose :id
    expose :overseer_step_id
    expose :exit_status
    expose :pass

    expose :stdout

    expose :stdin
    expose :expected_output

    expose :stdout_sha256
    expose :stdin_sha256
    expose :expected_output_sha256
  end
end
