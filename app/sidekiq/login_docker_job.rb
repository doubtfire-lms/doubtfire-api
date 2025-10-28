class LoginDockerJob
  include Sidekiq::Job
  include Sidekiq::Status::Worker
  include LogHelper
  include ApplicationHelper

  sidekiq_options lock: :until_executed,
                  lock_args_method: ->(args) { args },
                  on_conflict: :reject,
                  retry: false

  def perform
    `echo \"${DOCKER_TOKEN}\" | docker login --username ${DOCKER_USER} --password-stdin ${DOCKER_PROXY_URL} >> /dev/null 2>&1`
  rescue StandardError => e
    logger.error e
    raise e
  end
end
