require 'grape'

class SidekiqApi < Grape::API
  helpers AuthenticationHelpers
  helpers AuthorisationHelpers

  before do
    authenticated?
  end

  desc 'Returns job information for a Sidekiq job'
  params do
    requires :id, type: String, desc: 'Id of the sidekiq job'
  end
  get '/sidekiq/:id' do
    job_id = params[:id]
    job_data = Sidekiq::Status.get_all(job_id)

    initiator = Sidekiq::Status.get(job_id, :initiator)
    if current_user.id != initiator.to_i
      error!({ error: 'You do not have permission to access this job' }, 403)
    end

    present job_data.with_indifferent_access, with: Entities::SidekiqJobEntity
  end
end
