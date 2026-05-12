class PollCommunicationSetSchedulesJob
  include Sidekiq::Job

  sidekiq_options lock: :until_executed,
                  lock_args_method: ->(_args) { ['poll-communication-set-schedules'] },
                  on_conflict: :reject,
                  retry: 1

  def perform
    CommunicationSetSchedule
      .includes(:communication_set)
      .active
      .due(Time.zone.now)
      .find_each do |schedule|
        ExecuteCommunicationSetScheduleJob.perform_async(schedule.id)
      end
  end
end
