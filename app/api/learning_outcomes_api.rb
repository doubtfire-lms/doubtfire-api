require 'grape'

class LearningOutcomesApi < Grape::API
  helpers AuthenticationHelpers
  helpers AuthorisationHelpers
  helpers MimeCheckHelpers
  helpers CsvHelper

  before do
    authenticated?
  end

  desc 'Get all global outcomes'
  get '/global/outcomes' do
    # can be read by any logged in user
    present LearningOutcome.global_outcomes, with: Entities::LearningOutcomeEntity
  end

  desc 'Add an outcome to a specified context (unit, task_definition, etc.)'
  params do
    requires :abbreviation, type: String, desc: 'The ILO''s abbreviation'
    requires :short_description, type: String, desc: 'The ILO''s short_description'
    optional :full_outcome_description, type: String, desc: 'The ILO''s full_outcome_description'
    optional :linked_outcome_ids, type: Array[Integer], desc: 'The ids of the linked outcome ids'
    requires :context_type_plural, type: String, desc: 'The context - a unit or task_definition', values: %w[units task_definitions]
  end
  post '/:context_type_plural/:context_id/outcomes' do
    # find context model dynamically
    context_type = params[:context_type_plural].singularize.camelize
    context_model = context_type.classify.constantize.find(params[:context_id])

    unless authorise? current_user, context_model, :update
      error!({ error: 'You are not authorised to create outcomes in this context.' }, 403)
    end

    outcome_params = declared(params, include_missing: false).except(:linked_outcome_ids, :context_type_plural)
    outcome_params[:context_type] = context_type

    learning_outcome = context_model.learning_outcomes.create!(outcome_params)
    learning_outcome.update_linked_outcomes(params[:linked_outcome_ids])

    present learning_outcome, with: Entities::LearningOutcomeEntity
  end

  desc "Add a global outcome"
  params do
    requires :abbreviation, type: String, desc: 'The ILO''s abbreviation'
    requires :short_description, type: String, desc: 'The ILO''s short_description'
    optional :full_outcome_description, type: String, desc: 'The ILO''s full_outcome_description'
    optional :linked_outcome_ids, type: Array[Integer], desc: 'The ids of the linked outcome ids'
  end
  post '/global/outcomes' do
    # find learning outcomes with a null context_type and context_id

    unless authorise? current_user, User, :update_glos
      error!({ error: 'You are not authorised to create global outcomes.' }, 403)
    end

    outcome_params = declared(params, include_missing: false).except(:linked_outcome_ids)
    outcome_params[:context_type] = nil
    outcome_params[:context_id] = nil
    glo = LearningOutcome.create!(outcome_params)
    glo.update_linked_outcomes(params[:linked_outcome_ids])

    present glo, with: Entities::LearningOutcomeEntity
  end

  desc 'Update an outcome in a specified context (unit, course, task_definition, ect.)'
  params do
    requires :context_id, type: Integer, desc: 'The id of the context'
    optional :abbreviation, type: String, desc: 'The ILO''s abbreviation'
    optional :short_description, type: String, desc: 'The ILO''s short_description'
    optional :full_outcome_description, type: String, desc: 'The ILO''s full_outcome_description'
    optional :linked_outcome_ids, type: Array[Integer], desc: 'The ids of the linked outcome ids'
    # optional :ilo_number, type: Integer, desc: 'The ILO''s new sequence number'
    requires :context_type_plural, type: String, desc: 'The context - a unit or task_definition', values: %w[units task_definitions]
  end
  put '/:context_type_plural/:context_id/outcomes/:id' do
    # find context model dynamically
    context_type = params[:context_type_plural].singularize.camelize
    context_model = context_type.classify.constantize.find(params[:context_id])

    unless authorise? current_user, context_model, :update
      error!({ error: 'You are not authorised to update outcomes in this context.' }, 403)
    end

    learning_outcome = context_model.learning_outcomes.find(params[:id])
    error!({ error: 'Unable to locate outcome requested.' }, 405) if learning_outcome.nil?

    learning_outcome_parameters = declared(params, include_missing: false).except(:linked_outcome_ids, :context_id, :context_type_plural, :context_type)

    learning_outcome.update!(learning_outcome_parameters)

    if params[:linked_outcome_ids]
      learning_outcome.update_linked_outcomes(params[:linked_outcome_ids])
    end

    present learning_outcome, with: Entities::LearningOutcomeEntity
  end

  desc 'Update a global outcome'
  params do
    optional :abbreviation, type: String, desc: 'The ILO''s abbreviation'
    optional :short_description, type: String, desc: 'The ILO''s short_description'
    optional :full_outcome_description, type: String, desc: 'The ILO''s full_outcome_description'
    optional :linked_outcome_ids, type: Array[Integer], desc: 'The ids of the linked outcome ids'
  end
  put '/global/outcomes/:id' do
    # find learning outcomes with a null context_type and context_id
    glo = LearningOutcome.find(params[:id])

    unless authorise? current_user, glo, :update_glos
      error!({ error: 'You are not authorised to update global outcomes.' }, 403)
    end

    ilo_parameters = declared(params, include_missing: false).except(:linked_outcome_ids)
    glo.update!(ilo_parameters)

    if params[:linked_outcome_ids]
      learning_outcome.update_linked_outcomes(params[:linked_outcome_ids])
    end
    present glo, with: Entities::LearningOutcomeEntity
  end

  desc 'Delete an outcome from a specified context (unit, course, task_definition, ect.)'
  params do
    requires :context_id, type: Integer, desc: 'The id of the context'
    requires :id, type: Integer, desc: 'The id for the outcome you wish to delete'
    requires :context_type_plural, type: String, desc: 'The context - a unit or task_definition', values: %w[units task_definitions]
  end
  delete '/:context_type_plural/:context_id/outcomes/:id' do
    # find context model dynamically
    context_type = params[:context_type_plural].singularize.camelize
    context_model = context_type.classify.constantize.find(params[:context_id])

    unless authorise? current_user, context_model, :update
      error!({ error: 'You are not authorised to delete outcomes in this context.' }, 403)
    end

    ilo = context_model.learning_outcomes.find(params[:id])
    error!({ error: 'Unable to locate outcome requested.' }, 405) if ilo.nil?

    ilo.destroy
    nil
  end

  desc 'Delete a global outcome'
  params do
    requires :id, type: Integer, desc: 'The id for the outcome you wish to delete'
  end
  delete '/global/outcomes/:id' do
    # find learning outcomes with a null context_type and context_id
    glo = LearningOutcome.find(params[:id])

    unless authorise? current_user, glo, :update_glos
      error!({ error: 'You are not authorised to delete global outcomes.' }, 403)
    end

    glo.destroy
    nil
  end

  desc 'Download the outcomes for a specified context (unit, course, task_definition, ect.) to a csv' # add a way to get nested outcomes aswell
  params do
    requires :context_id, type: Integer, desc: 'The id of the context'
    optional :includes_tlos, type: Boolean, desc: 'Include nested task learning outcomes in the export'
    requires :context_type_plural, type: String, desc: 'The context - a unit or task_definition', values: %w[units task_definitions]
  end
  get '/:context_type_plural/:context_id/outcomes/csv' do
    # find context model dynamically
    include_tlos = params[:includes_tlos] || false
    context_type = params[:context_type_plural].singularize.camelize
    context_model = context_type.classify.constantize.find(params[:context_id])

    unless authorise? current_user, context_model, :update
      error!({ error: 'You are not authorised to download outcomes for this context.' }, 403)
    end

    title = context_model.respond_to?(:export_title) ? context_model.export_title : 'LearningOutcomes'

    content_type 'application/octet-stream'
    header['Content-Disposition'] = "attachment; filename=#{title}-LearningOutcomes.csv"
    header['Access-Control-Expose-Headers'] = 'Content-Disposition'
    env['api.format'] = :binary

    context_model.export_learning_outcome_to_csv(include_tlos: include_tlos)
  end

  desc 'Upload the outcomes for a specified context (unit, course, task_definition, ect.) from a csv' # make it a generic upload for any context
  params do
    requires :file, type: File, desc: 'CSV upload file.'
    requires :context_id, type: Integer, desc: 'The id of the context'
    requires :context_type_plural, type: String, desc: 'The context - a unit or task_definition', values: %w[units task_definitions]
  end
  post '/:context_type_plural/:context_id/outcomes/csv' do
    # check mime is correct before uploading
    ensure_csv!(params[:file][:tempfile])

    # find context model dynamically
    context_type = params[:context_type_plural].singularize.camelize
    context_model = context_type.classify.constantize.find(params[:context_id])

    unless authorise? current_user, context_model, :upload_csv
      error!({ error: 'Not authorised to upload CSV of outcomes' }, 403)
    end

    # Actually import...
    context_model.import_outcomes_from_csv(params[:file][:tempfile])
  end
end
