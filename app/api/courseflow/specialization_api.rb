require 'grape'
module Courseflow
  class SpecializationApi < Grape::API

    format :json
    helpers AuthenticationHelpers
    helpers AuthorisationHelpers

    before do
      authenticated?
    end

    desc "Get all specialization data"
    get '/specialization' do
      specializations = Specialization.all # get all specializations in the database
      present specializations, with: Entities::SpecializationEntity # present the specializations using the SpecializationEntity
    end

    desc "Get specialization by ID"
    params do
      requires :specializationId, type: Integer, desc: "Specialization ID"
    end
    get '/specialization/specializationId/:specializationId' do
      specialization = Specialization.find(params[:specializationId]) # find the specialization by ID
      present specialization, with: Entities::SpecializationEntity      # present the specialization using the SpecializationEntity
    end

    desc "Add a new specialization"
    params do # define the parameters required to create a new specialization
      requires :specialization, type: String
    end
    post '/specialization' do
      unless authorise? current_user, User, :handle_courseflow
        error!({ error: 'Not authorised to add a specialization' }, 403)
      end
      specialization = Specialization.new(params) # create a new specialization with the provided params
      if specialization.save
        present specialization, with: Entities::SpecializationEntity # if the specialization is saved, present the specialization using the SpecializationEntity
      else
        error!({ error: "Failed to create specialization", details: specialization.errors.full_messages }, 400) # if the specialization is not saved, return an error with the full error messages
      end
    end

    desc "Update an existing specialization via its ID"
    params do # define the parameters required to update a specialization
      requires :specializationId, type: Integer, desc: "Specialization ID"
      requires :specialization, type: String
    end
    put '/specialization/specializationId/:specializationId' do
      unless authorise? current_user, User, :handle_courseflow
        error!({ error: 'Not authorised to update specializations' }, 403)
      end
      specialization = Specialization.find(params[:specializationId]) # find the specialization by ID
      if specialization.update(specialization: params[:specialization]) # update the specialization with the provided params
        present specialization, with: Entities::SpecializationEntity # if the specialization is updated, present the specialization using the SpecializationEntity
      else
        error!({ error: "Failed to update specialization", details: specialization.errors.full_messages }, 400) # if the specialization is not updated, return an error with the full error messages
      end
    end

    desc "Delete an existing specialization via its ID"
    params do # define the parameters required to delete a specialization
      requires :specializationId, type: Integer, desc: "Specialization ID"
    end
    delete '/specialization/specializationId/:specializationId' do
      unless authorise? current_user, User, :handle_courseflow
        error!({ error: 'Not authorised to delete specializations' }, 403)
      end
      specialization = Specialization.find(params[:specializationId]) # find the specialization by ID
      specialization.destroy # delete the specialization
      { message: "Specialization with ID #{params[:specializationId]} has been deleted" } # return a message saying the course was deleted
    end
  end
end
