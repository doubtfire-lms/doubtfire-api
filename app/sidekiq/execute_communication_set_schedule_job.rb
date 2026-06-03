class ExecuteCommunicationSetScheduleJob
  include Sidekiq::Job

  sidekiq_options lock: :until_executed,
                  lock_args_method: ->(args) { [args.first, 'communication-set-schedule'] },
                  on_conflict: :reject,
                  retry: 1

  def perform(schedule_id)
    schedule = CommunicationSetSchedule.find(schedule_id)
    return unless schedule.active?
    return unless schedule.unit.active?

    now = Time.zone.now
    return unless schedule.due?(now)

    ExecuteCommunicationSetJob.perform_async(schedule.communication_set_id)
    schedule.update!(
      last_enqueued_at: now,
      last_run_at: now,
      next_run_at: schedule.next_occurrence_after(now + 1.second)
    )
  end
end
