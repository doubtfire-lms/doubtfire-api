require 'grape'
module Courseflow
  class RequirementSetApi < Grape::API
    format :json
    helpers AuthenticationHelpers
    helpers AuthorisationHelpers

    before do
      authenticated?
    end

    desc "Get all requirement set data"
    get '/requirementset' do
      requirement_set = RequirementSet.all # get all requirement sets in the database
      present requirement_set, with: Entities::RequirementSetEntity # present the requirement sets using the RequirementSetEntity
    end

    desc "Get requirement set by Group ID"
    params do
      requires :requirementSetGroupId, type: Integer, desc: "Requirement Set Group ID"
    end
    get '/requirementset/requirementSetGroupId/:requirementSetGroupId' do
      requirement_set = RequirementSet.where(requirementSetGroupId: params[:requirementSetGroupId]) # find the requirement set by ID
      if requirement_set.empty?
        error!({ error: "Requirement Set with group ID #{params[:requirementSetGroupId]} not found" }, 404) # if the requirement set group is not found, return an error
      end
      present requirement_set, with: Entities::RequirementSetEntity      # present the requirement set using the RequirementSetEntity
    end

    desc "Add a new requirement set"
    params do # define the parameters required to create a new requirement set
      requires :requirementSetGroupId, type: Integer
      requires :description, type: String
      requires :unitId, type: Integer
      requires :requirementId, type: Integer
    end
    post '/requirementset' do
      unless authorise? current_user, User, :handle_courseflow # check if the user is authorised to manage courseflow
        error!({ error: 'Not authorised to add a requirement set' }, 403)
      end
      requirement_set = RequirementSet.new(params) # create a new requirement set with the provided params
      if requirement_set.save
        present requirement_set, with: Entities::RequirementSetEntity # if the requirement set is saved, present the requirement set using the RequirementSetEntity
      else
        error!({ error: "Failed to create requirement set", details: requirement_set.errors.full_messages }, 400) # if the requirement set is not saved, return an error with the full error messages
      end
    end

    desc "Update an existing requirement set via its ID"
    params do # define the parameters required to update a requirement set
      requires :requirementSetId, type: Integer, desc: "Requirement Set ID"
      requires :requirementSetGroupId, type: Integer
      requires :description, type: String
      requires :unitId, type: Integer
      requires :requirementId, type: Integer
    end
    put '/requirementset/requirementSetId/:requirementSetId' do
      unless authorise? current_user, User, :handle_courseflow # check if the user is authorised to manage courseflow
        error!({ error: 'Not authorised to update a requirement set' }, 403)
      end
      requirement_set = RequirementSet.find(params[:requirementSetId]) # find the requirement set by ID
      if requirement_set.update(requirementSetGroupId: params[:requirementSetGroupId], description: params[:description], unitId: params[:unitId], requirementId: params[:requirementId]) # update the requirement set with the provided params
        present requirement_set, with: Entities::RequirementSetEntity # if the requirement set is updated, present the requirement set using the RequirementSetEntity
      else
        error!({ error: "Failed to update requirement set", details: requirement_set.errors.full_messages }, 400) # if the requirement set is not updated, return an error with the full error messages
      end
    end

    desc "Delete a requirement set by ID"
    params do # define the parameters required to delete a requirement set
      requires :requirementSetId, type: Integer, desc: "Requirement Set ID"
    end
    delete '/requirementset/requirementSetId/:requirementSetId' do
      unless authorise? current_user, User, :handle_courseflow # check if the user is authorised to manage courseflow
        error!({ error: 'Not authorised to delete a requirement set' }, 403)
      end
      requirement_set = RequirementSet.find(params[:requirementSetId]) # find the requirement set by ID
      requirement_set.destroy # if the requirement set is deleted
      { message: "Requirement Set with ID #{params[:requirementSetId]} has been deleted" } # return a message saying the course was deleted
    end

  end
end
