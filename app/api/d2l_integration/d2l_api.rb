require 'grape'

module D2lIntegration

  # The D2l API provides the frontend with the ability to register
  # integration details to connect units with D2L. This will allow
  # grade book items to be copied from portfolio results to D2L.
  class D2lApi < Grape::API
    helpers AuthenticationHelpers
    helpers AuthorisationHelpers
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

      present unit.d2l_assessment_mapping, with: D2lIntegration::Entities::D2lEntity
    end

    desc 'Create a D2L assessment mapping for a unit'
    params do
      requires :org_unit_id, type: String, desc: 'The org unit id for the D2L unit'
    end
    post '/units/:unit_id/d2l' do
      unit = Unit.find(params[:unit_id])

      unless authorise?(current_user, unit, :update)
        error!({ error: 'Not authorised to add D2L details' }, 403)
      end

      d2l = D2lAssessmentMapping.create!(unit: unit, org_unit_id: params[:org_unit_id])
      present d2l, with: D2lIntegration::Entities::D2lEntity
    end

    desc 'Delete a D2L assessment mapping for a unit'
    delete '/units/:unit_id/d2l' do
      unit = Unit.find(params[:unit_id])

      unless authorise?(current_user, unit, :update)
        error!({ error: 'Not authorised to delete D2L details' }, 403)
      end

      d2l = unit.d2l_assessment_mapping
      d2l.destroy if d2l.present?
      status 204
    end

    desc 'Update a D2L assessment mapping for a unit'
    params do
      requires :org_unit_id, type: String, desc: 'The org unit id for the D2L unit'
    end
    put '/units/:unit_id/d2l' do
      unit = Unit.find(params[:unit_id])

      unless authorise?(current_user, unit, :update)
        error!({ error: 'Not authorised to update D2L details' }, 403)
      end

      d2l = unit.d2l_assessment_mapping
      d2l.update!(org_unit_id: params[:org_unit_id])
      present d2l, with: D2lIntegration::Entities::D2lEntity
    end
  end
end
