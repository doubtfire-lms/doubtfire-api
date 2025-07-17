module Entities
  class SidekiqJobEntity < Grape::Entity
    expose :jid, as: :id
    expose :status
    expose :pct_complete
    expose :message

    expose :at, as: :processed_count
    expose :total, as: :total_count
    expose :working_at, as: :createdAt
    expose :update_time, as: :updatedAt

    expose :worker, as: :job_class

    expose :result
  end
end
