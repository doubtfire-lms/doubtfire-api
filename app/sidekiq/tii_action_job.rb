class TiiActionJob
  include Sidekiq::Job

  def perform(id)
    action = TiiAction.find(id)

    action.perform
  end
end
