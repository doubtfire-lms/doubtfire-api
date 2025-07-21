module SidekiqHelper
  def setup_job(job_id)
    error!({ error: "Failed to create job. Job may already be in progress." }, 409) if job_id.nil?
    job = Sidekiq::Status.get_all(job_id)
    Sidekiq::Status.send(:store_for_id, job_id, { initiator: current_user.id }, nil)
    # Sidekiq::Status.store_for_id(job_id, { initiator: current_user.id }, nil)
    job.with_indifferent_access
  end
end
