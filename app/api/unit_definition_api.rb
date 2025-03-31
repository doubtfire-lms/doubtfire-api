require 'grape'

  class UnitDefinitionApi < Grape::API

    format :json
    helpers AuthenticationHelpers
    helpers AuthorisationHelpers

    before do
      authenticated?
    end

    desc "Get all unit definitions"
    get '/unit_definition' do
      unit_definitions = UnitDefinition.all
      present unit_definitions, with: Entities::UnitDefinitionEntity
    end

    desc "Get unit definition by ID"
    params do
      requires :unitDefinitionId, type: Integer, desc: "Unit Definition ID"
    end
    get '/unit_definition/unitDefinitionId/:unitDefinitionId' do
      unit_definition = UnitDefinition.find(params[:unitDefinitionId])
      present unit_definition, with: Entities::UnitDefinitionEntity
    end

    desc "Get units based on unit definition ID"
    params do
      requires :unitDefinitionId, type: Integer, desc: "Unit Definition ID"
    end
    get '/unit_definition/:unitDefinitionId/units' do
      unit_definition_id = params[:unitDefinitionId]
      units = Unit.where(unit_definition_id: unit_definition_id)
      present units, with: Entities::UnitEntity, user: current_user, summary_only: true, in_unit: true
    end

    desc "Get unit definitions that match search params"
    params do
      optional :code, type: String, desc: "Unit Definition code"
      optional :name, type: String, desc: "Unit Definition name"
    end
    get '/unit_definition/search' do
      unit_definitions = UnitDefinition.all

      unit_definitions = unit_definitions.where("code LIKE :code", code: "%#{params[:code]}%") if params[:code].present?
      unit_definitions = unit_definitions.where("name LIKE :name", name: "%#{params[:name]}%") if params[:name].present?

      present unit_definitions, with: Entities::UnitDefinitionEntity
    end

    desc "Add a new unit definition"
    params do
      requires :name, type: String
      requires :description, type: String
      requires :code, type: String
    end
    post '/unit_definition' do
      unless authorise? current_user, User, :handle_courseflow
        error!({ error: 'Not authorised to create a unit definition' }, 403)
      end
      unit_definition = UnitDefinition.new(params)
      if unit_definition.save
        present unit_definition, with: Entities::UnitDefinitionEntity
      else
        error!({ error: "Failed to create unit definition", details: unit_definition.errors.full_messages }, 400)
      end
    end

    desc "Add a new unit to a unit definition"
    params do
      requires :unitDefinitionId, type: Integer, desc: "Unit Definition ID"
      requires :name, type: String
      requires :description, type: String
      requires :code, type: String
    end
    post '/unit_definition/:unitDefinitionId/unit' do
      unless authorise? current_user, User, :handle_courseflow
        error!({ error: 'Not authorised to create a unit' }, 403)
      end
      unit_definition = UnitDefinition.find(params[:unitDefinitionId])
      unit = unit_definition.units.new(params)
      if unit.save
        present unit, with: Entities::UnitEntity
      else
        error!({ error: "Failed to create unit", details: unit.errors.full_messages }, 400)
      end
    end

    desc "Update an existing unit definition via its ID"
    params do
      requires :unitDefinitionId, type: Integer, desc: "Unit Definition ID"
      requires :name, type: String
      requires :description, type: String
      requires :code, type: String
    end
    put '/unit_definition/unitDefinitionId/:unitDefinitionId' do
      unless authorise? current_user, User, :handle_courseflow
        error!({ error: 'Not authorised to update a unit definition' }, 403)
      end
      unit_definition = UnitDefinition.find(params[:unitDefinitionId])
      error!({ error: "Unit Definition not found" }, 404) unless unit_definition

      if unit_definition.update(name: params[:name], description: params[:description], code: params[:code])
        present unit_definition, with: Entities::UnitDefinitionEntity
      else
        error!({ error: "Failed to update unit definition", details: unit_definition.errors.full_messages }, 400)
      end
    end

    desc "Deletes an existing unit definition via its ID"
    params do
      requires :unitDefinitionId, type: Integer, desc: "Unit Definition ID"
    end
    delete '/unit_definition/unitDefinitionId/:unitDefinitionId' do
      unless authorise? current_user, User, :handle_courseflow
        error!({ error: 'Not authorised to delete a unit definition' }, 403)
      end
      unit_definition = UnitDefinition.find(params[:unitDefinitionId])
      unit_definition.destroy
      { message: "Unit Definition with ID #{params[:unitDefinitionId]} has been deleted" }
    end

    desc "Remove a unit from a unit definition"
    params do
      requires :unitDefinitionId, type: Integer, desc: "Unit Definition ID"
      requires :unitId, type: Integer, desc: "Unit ID"
    end
    delete '/unit_definition/:unitDefinitionId/unit/:unitId' do
      unless authorise? current_user, User, :handle_courseflow
        error!({ error: 'Not authorised to delete a unit' }, 403)
      end
      unit_definition = UnitDefinition.find(params[:unitDefinitionId])
      unit = unit_definition.units.find(params[:unitId])
      unit.destroy
      { message: "Unit with ID #{params[:unitId]} has been deleted from Unit Definition with ID #{params[:unitDefinitionId]}" } #change to just remove the unit definition id from the unit
    end
  end
