require 'grape'

class LearningOutcomesApi < Grape::API
  helpers AuthenticationHelpers
  helpers AuthorisationHelpers
  helpers MimeCheckHelpers
  helpers CsvHelper

  before do
    authenticated?
  end

  route :context_type_plural, values: %w[units task_definitions] do
    params[:context_type].pluralize
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
  end
  post '/:context_type_plural/:context_id/outcomes' do
    # find context model dynamically
    context_type = params[:context_type_plural].singularize.camelize
    context_model = context_type.classify.constantize.find(params[:context_id])

    unless authorise? current_user, context_model, :update
      error!({ error: 'You are not authorised to create outcomes in this context.' }, 403)
    end

    outcome_params = declared(params, include_missing: false).except(:linked_outcome_ids)
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
    glo = context_model.learning_outcomes.create!(outcome_params)
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

    learning_outcome_parameters = ActionController::Parameters.new(params)
                                                 .permit(
                                                   :abbreviation,
                                                   :short_description,
                                                   :full_outcome_description
                                                 )
    # context_model.move_ilo(ilo, params[:ilo_number]) if params[:ilo_number]
    learning_outcome.update!(learning_outcome_parameters)

    if params[:linked_outcome_ids]
      # delete all existing links
      # LearningOutcomeLink.where(source_id: learning_outcome.id).destroy_all # change for different method, move to learning outcome link

      existing_links = LearningOutcomeLink.where(source_id: learning_outcome.id).pluck(:target_id)

      links_to_delete = existing_links - params[:linked_outcome_ids]
      links_to_create = params[:linked_outcome_ids] - existing_links

      LearningOutcomeLink.where(source_id: learning_outcome.id, target_id: links_to_delete).destroy_all

      links_to_create.each do |linked_outcome_id|
        begin
          LearningOutcomeLink.create!(source_id: learning_outcome.id, target_id: linked_outcome_id)
        rescue ActiveRecord::RecordInvalid => e
          Rails.logger.warn "Failed to link learning outcome #{learning_outcome.id} to learning outcome #{linked_outcome_id}: #{e.message}"
        end
      end
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

    ilo_parameters = ActionController::Parameters.new(params)
                                                 .permit(
                                                   :abbreviation,
                                                   :short_description,
                                                   :full_outcome_description
                                                 )
    glo.update!(ilo_parameters)

    if params[:linked_outcome_ids]
      # delete all existing links
      # LearningOutcomeLink.where(source_id: learning_outcome.id).destroy_all # change for different method, move to learning outcome link

      existing_links = LearningOutcomeLink.where(source_id: glo.id).pluck(:target_id)

      links_to_delete = existing_links - params[:linked_outcome_ids]
      links_to_create = params[:linked_outcome_ids] - existing_links

      LearningOutcomeLink.where(source_id: glo.id, target_id: links_to_delete).destroy_all

      links_to_create.each do |linked_outcome_id|
        begin
          LearningOutcomeLink.create!(source_id: glo.id, target_id: linked_outcome_id)
        rescue ActiveRecord::RecordInvalid => e
          Rails.logger.warn "Failed to link learning outcome #{glo.id} to learning outcome #{linked_outcome_id}: #{e.message}"
        end
      end
    end
    present glo, with: Entities::LearningOutcomeEntity
  end

=begin
  desc 'Delete an outcome from a unit'
  params do
    requires :unit_id, type: Integer, desc: 'The id for the unit'
    requires :id, type: Integer, desc: 'The id for the outcome you wish to delete'
  end
  delete '/units/:unit_id/outcomes/:id' do
    unit = Unit.find(params[:unit_id])
    error!({ error: 'Unable to locate requested unit.' }, 405) if unit.nil?

    unless authorise? current_user, unit, :update
      error!({ error: 'You are not authorised to delete outcomes in this unit.' }, 403)
    end

    ilo = unit.learning_outcomes.find(params[:id])
    error!({ error: 'Unable to locate outcome requested.' }, 405) if ilo.nil?

    ilo.destroy
    nil
  end
=end

  desc 'Delete an outcome from a specified context (unit, course, task_definition, ect.)'
  params do
    requires :context_id, type: Integer, desc: 'The id of the context'
    requires :id, type: Integer, desc: 'The id for the outcome you wish to delete'
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

=begin
  desc 'Download the outcomes for a unit to a csv'
  get '/units/:unit_id/outcomes/csv' do
    unit = Unit.find(params[:unit_id])
    error!({ error: 'Unable to locate requested unit.' }, 405) if unit.nil?

    unless authorise? current_user, unit, :update
      error!({ error: 'You are not authorised to download outcomes for this unit.' }, 403)
    end

    content_type 'application/octet-stream'
    header['Content-Disposition'] = "attachment; filename=#{unit.code}-LearningOutcomes.csv"
    header['Access-Control-Expose-Headers'] = 'Content-Disposition'
    env['api.format'] = :binary
    unit.export_learning_outcome_to_csv
  end
=end

  desc 'Download the outcomes for a specified context (unit, course, task_definition, ect.) to a csv' # add a way to get nested outcomes aswell
  params do
    requires :context_id, type: Integer, desc: 'The id of the context'
    optional :includes_tlos, type: Boolean, desc: 'Include nested task learning outcomes in the export'
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

=begin
desc 'Upload the outcomes for a unit from a csv'
  params do
    requires :file, type: File, desc: 'CSV upload file.'
    requires :unit_id, type: Integer, desc: 'The unit to upload tasks to'
  end
  post '/units/:unit_id/outcomes/csv' do
    # check mime is correct before uploading
    ensure_csv!(params[:file][:tempfile])

    unit = Unit.find(params[:unit_id])

    unless authorise? current_user, unit, :upload_csv
      error!({ error: 'Not authorised to upload CSV of outcomes' }, 403)
    end

    # Actually import...
    unit.import_outcomes_from_csv(params[:file][:tempfile])
  end
=end

  desc 'Upload the outcomes for a specified context (unit, course, task_definition, ect.) from a csv' # make it a generic upload for any context
  params do
    requires :file, type: File, desc: 'CSV upload file.'
    requires :context_id, type: Integer, desc: 'The id of the context'
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
