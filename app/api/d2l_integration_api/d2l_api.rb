require 'grape'

module D2lIntegrationApi
  # The D2l API provides the frontend with the ability to register
  # integration details to connect units with D2L. This will allow
  # grade book items to be copied from portfolio results to D2L.
  class D2lApi < Grape::API
    helpers AuthenticationHelpers
    helpers AuthorisationHelpers
    helpers FileStreamHelper
    include LogHelper

    before do
      authenticated?
    end

    desc 'Get the D2L assessment mapping for a unit'
    get '/units/:unit_id/d2l' do
      unit = Unit.find(params[:unit_id])

      unless authorise?(current_user, unit, :update)
        error!({ error: 'Not authorised to view D2L details' }, 403)
      end

      present unit.d2l_assessment_mapping, with: D2lIntegrationApi::Entities::D2lEntity
    end

    desc 'Create a D2L assessment mapping for a unit'
    params do
      requires :org_unit_id, type: String, desc: 'The org unit id for the D2L unit'
      optional :grade_object_id, type: Numeric, desc: 'The grade object id for the D2L unit'
    end
    post '/units/:unit_id/d2l' do
      unit = Unit.find(params[:unit_id])

      unless authorise?(current_user, unit, :update)
        error!({ error: 'Not authorised to add D2L details' }, 403)
      end

      accepted_params = ActionController::Parameters.new(params).permit(:unit_id, :org_unit_id, :grade_object_id)

      d2l = D2lAssessmentMapping.create!(accepted_params)
      present d2l, with: D2lIntegrationApi::Entities::D2lEntity
    end

    desc 'Delete a D2L assessment mapping for a unit'
    delete '/units/:unit_id/d2l/:id' do
      unit = Unit.find(params[:unit_id])

      unless authorise?(current_user, unit, :update)
        error!({ error: 'Not authorised to delete D2L details' }, 403)
      end

      d2l = unit.d2l_assessment_mapping

      if d2l.id != params[:id].to_i
        error!({ error: 'D2L details not found' }, 404)
      end

      d2l.destroy if d2l.present?
      status 204
    end

    desc 'Update a D2L assessment mapping for a unit'
    params do
      optional :org_unit_id, type: String, desc: 'The org unit id for the D2L unit'
      optional :grade_object_id, type: Numeric, desc: 'The grade object id for the D2L unit'
    end
    put '/units/:unit_id/d2l/:id' do
      unit = Unit.find(params[:unit_id])

      unless authorise?(current_user, unit, :update)
        error!({ error: 'Not authorised to update D2L details' }, 403)
      end

      d2l = unit.d2l_assessment_mapping

      if d2l.id != params[:id].to_i
        error!({ error: 'D2L details not found' }, 404)
      end

      accepted_params = ActionController::Parameters.new(params).permit(:org_unit_id, :grade_object_id)

      d2l.update!(accepted_params)
      present d2l, with: D2lIntegrationApi::Entities::D2lEntity
    end

    desc 'Initiate a login to D2L as a convenor or admin'
    post '/d2l/login_url' do
      unless authorise? current_user, User, :convene_units
        error!({ error: 'Not authorised to login to D2L' }, 403)
      end

      begin
        response = D2lIntegration.login_url(current_user)
      rescue StandardError => e
        error!({ error: e.message }, 500)
      end

      present response, with: Grape::Presenters::Presenter
    end

    desc 'Trigger the posting of grades to D2L'
    post '/units/:unit_id/d2l/grades' do
      unit = Unit.find(params[:unit_id])

      unless authorise?(current_user, unit, :update)
        error!({ error: 'Not authorised to post grades to D2L' }, 403)
      end

      if unit.d2l_assessment_mapping.blank?
        error!({ error: 'Configure D2L details for unit before starting transfer' }, 403)
      end

      token = current_user.user_oauth_tokens.where(provider: :d2l).last
      if token.blank? || token.expires_at < 10.minutes.from_now
        error!({ error: 'Login to D2L before transferring results' }, 403)
      end

      D2lPostGradesJob.perform_async(unit.id, current_user.id)

      status 202
    end

    desc 'Get the result of a grade transfer to D2L'
    get '/units/:unit_id/d2l/grades' do
      unit = Unit.find(params[:unit_id])

      unless authorise?(current_user, unit, :update)
        error!({ error: 'Not authorised to view grade transfer results' }, 403)
      end

      file_path = D2lIntegration.result_file_path(unit)
      unless File.exist?(file_path)
        error!({ error: 'No grade transfer result found' }, 404)
      end

      content_type 'text/csv'

      stream_file(file_path)
    end

    desc 'Determing if grade results are available for a unit'
    get '/units/:unit_id/d2l/grades/available' do
      unit = Unit.find(params[:unit_id])

      unless authorise?(current_user, unit, :update)
        error!({ error: 'Not authorised to view grade transfer results' }, 403)
      end

      file_path = D2lIntegration.result_file_path(unit)
      response = {
        available: File.exist?(file_path),
        running: D2lIntegration.d2l_grade_job_present?(unit)
      }

      present response, with: Grape::Presenters::Presenter
    end

    desc 'Determing if unit is weighted'
    get '/units/:unit_id/d2l/grades/weighted' do
      unit = Unit.find(params[:unit_id])

      unless authorise?(current_user, unit, :update)
        error!({ error: 'Not authorised to view unit details' }, 403)
      end

      d2l = unit.d2l_assessment_mapping

      return false unless d2l.present? && d2l.org_unit_id.present?

      present D2lIntegration.grade_weighted?(d2l, current_user), with: Grape::Presenters::Presenter
    end

    desc 'Get D2L api endpoint'
    get '/d2l/endpoint' do
      unless authorise? current_user, User, :convene_units
        error!({ error: 'Not authorised to view D2L endpoint' }, 403)
      end

      present D2lIntegration.d2l_api_host, with: Grape::Presenters::Presenter
    end
  end
end
