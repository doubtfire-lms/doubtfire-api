class PullDockerImageJob
  include Sidekiq::Job
  include Sidekiq::Status::Worker
  include LogHelper
  include ApplicationHelper
  include FileHelper

  sidekiq_options lock: :until_executed,
                  lock_args_method: ->(args) { [args.first] },
                  on_conflict: :reject,
                  retry: false

  def perform(overseer_image_id)
    logger.info "Starting pull docker image job..."

    at(0)
    total(1)

    overseer_image = OverseerImage.find(overseer_image_id)
    overseer_image.pull_from_docker

    store(result: overseer_image.pulled_image_text)

    at(1)

    logger.info "Completed pull docker image job"
  rescue StandardError => e
    logger.error e
    raise e
  end
end
