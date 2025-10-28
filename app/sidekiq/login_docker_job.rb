require 'English'

class LoginDockerJob
  include Sidekiq::Job
  include Sidekiq::Status::Worker
  include LogHelper
  include ApplicationHelper

  sidekiq_options lock: :until_executed,
                  lock_args_method: ->(args) { args },
                  on_conflict: :reject,
                  retry: 1

  def perform
    command = "echo \"${DOCKER_TOKEN}\" | docker login --username ${DOCKER_USER} --password-stdin ${DOCKER_PROXY_URL}"
    response = `#{command} 2>&1`
    status = $CHILD_STATUS.exitstatus

    if status != 0
      logger.error("Docker login failed with status #{status}: #{response}")
      raise "Docker login failed: #{response}"
    end
  rescue StandardError => e
    logger.error e
    raise e
  end
end
