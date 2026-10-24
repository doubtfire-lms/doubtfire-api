require 'grape'
module Courseflow
  class RequirementApi < Grape::API
    format :json
    helpers AuthenticationHelpers
    helpers AuthorisationHelpers

    before do
      authenticated?
    end

    desc 'Get all requirements'
    get '/requirement' do
      present Requirement.all, with: Entities::RequirementEntity
    end

    desc 'Get requirements by unit ID'
    params do
      requires :unitId, type: Integer, desc: 'Unit ID'
    end
    get '/requirement/unitId/:unitId' do
      present Requirement.where(unitId: params[:unitId]), with: Entities::RequirementEntity
    end

    desc 'Get requirements by course ID'
    params do
      requires :courseId, type: Integer, desc: 'Course ID'
    end
    get '/requirement/courseId/:courseId' do
      present Requirement.where(courseId: params[:courseId]), with: Entities::RequirementEntity
    end

    desc 'Create a new requirement'
    params do
      requires :unitId, type: Integer
      requires :courseId, type: Integer
      requires :type, type: String
      requires :category, type: String
      requires :description, type: String
      optional :minimum, type: Integer
      optional :maximum, type: Integer
      requires :requirementSetGroupId, type: Integer
    end
    post '/requirement' do
      error!({ error: 'Not authorised' }, 403) unless authorise?(current_user, User, :handle_courseflow)
      req = Requirement.new(declared(params, include_missing: false))
      if req.save
        status 201
        present req, with: Entities::RequirementEntity
      else
        error!({ error: 'Failed to create requirement', details: req.errors.full_messages }, 400)
      end
    end

    desc 'Update a requirement'
    params do
      requires :id, type: Integer, desc: 'Requirement ID'
      optional :unitId, type: Integer
      optional :courseId, type: Integer
      optional :type, type: String
      optional :category, type: String
      optional :description, type: String
      optional :minimum, type: Integer
      optional :maximum, type: Integer
      optional :requirementSetGroupId, type: Integer
    end
    put '/requirement/:id' do
      error!({ error: 'Not authorised' }, 403) unless authorise?(current_user, User, :handle_courseflow)
      req = Requirement.find_by(id: params[:id])
      error!({ error: 'Requirement not found' }, 404) unless req
      if req.update(declared(params, include_missing: false).except(:id))
        present req, with: Entities::RequirementEntity
      else
        error!({ error: 'Failed to update requirement', details: req.errors.full_messages }, 400)
      end
    end

    desc 'Delete a requirement'
    params do
      requires :id, type: Integer, desc: 'Requirement ID'
    end
    delete '/requirement/:id' do
      error!({ error: 'Not authorised' }, 403) unless authorise?(current_user, User, :handle_courseflow)
      req = Requirement.find_by(id: params[:id])
      error!({ error: 'Requirement not found' }, 404) unless req
      req.destroy
      status 204
    end
  end
end
