class TiiActionJob
  include Sidekiq::Job

  def perform(id)
    action = TiiAction.find(id)

    action.perform
  rescue ActiveRecord::RecordNotFound => e
    logger.error "TiiActionJob: TiiAction with id #{id} not found"
  end
end
