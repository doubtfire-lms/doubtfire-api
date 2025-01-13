require 'grape'

class LearningOutcomesApi < Grape::API
  helpers AuthenticationHelpers
  helpers AuthorisationHelpers
  helpers MimeCheckHelpers

  before do
    authenticated?
  end

  route :context_type_plural, values: ['units', 'task_definitions', 'courses'] do
    params[:context_type].pluralize
  end

  desc "Get a specific learning outcome"
  get '/learning_outcomes/:id' do
    ilo = LearningOutcome.find(params[:id])

    unless authorise? current_user, ilo, :get_los
      error!({ error: 'You are not authorised to view this outcome.' }, 403)
    end

    present ilo, with: Entities::LearningOutcomeEntity
  end

  desc "Get all outcomes for a specified context (unit, course, task_definition, ect.)"
  params do
    requires :context_id, type: Integer, desc: 'The id of the context'
  end
  get '/:context_type_plural/:context_id/outcomes' do
    # find context model dynamically
    context_type = params[:context_type_plural].singularize.camelize
    context_model = context_type.classify.constantize.find(params[:context_id])

    unless authorise? current_user, context_model, :get_los
      error!({ error: 'You are not authorised to view outcomes in this context.' }, 403)
    end

    present context_model.learning_outcomes, with: Entities::LearningOutcomeEntity
  end

  desc "Get all global outcomes"
  get '/global/outcomes' do
    # find learning outcomes with a null context_type and context_id
    glos = LearningOutcome.where(context_type: nil, context_id: nil)
    if glos.nil?
      present []
    end

    unless authorise? current_user, User, :get_los
      error!({ error: 'You are not authorised to view global outcomes.' }, 403)
    end

    present glos, with: Entities::LearningOutcomeEntity
  end

  desc "Get all feedback chips for a learning outcome"
  get '/:context_type_plural/:context_id/outcomes/:id/feedback_chips' do
    # find context model dynamically
    context_type = params[:context_type_plural].singularize.camelize
    context_model = context_type.classify.constantize.find(params[:context_id])

    unless authorise? current_user, context_model, :get_los
      error!({ error: 'You are not authorised to view feedback chips in this context.' }, 403)
    end

    ilo = context_model.learning_outcomes.find(params[:id])
    feedback_chips = Feedback::FeedbackChip.where(learning_outcome_id: ilo.id)
    present feedback_chips, with: Feedback::Entities::FeedbackChipEntity
  end

=begin   desc 'Add an outcome to a unit'
  params do
    requires :unit_id, type: Integer, desc: 'The unit ID for which the ILO belongs to'
    requires :name, type: String, desc: 'The ILO''s name'
    requires :description, type: String, desc: 'The ILO''s description'
    optional :abbreviation, type: String, desc: 'The ILO''s new abbreviation'
  end
  post '/units/:unit_id/outcomes' do
    unit = Unit.find(params[:unit_id])

    unless authorise? current_user, unit, :update
      error!({ error: 'You are not authorised to create outcomes in this unit.' }, 403)
    end

    ilo = unit.add_ilo(params[:name], params[:description], params[:abbreviation])
    present ilo, with: Entities::LearningOutcomeEntity
  end
=end

  desc "Add an outcome to a specified context (unit, course, task_definition, ect.)"
  params do
    requires :context_id, type: Integer, desc: 'The id of the context'
    requires :context_type, type: String, values: ['Unit', 'Course', 'TaskDefinition'], desc: 'The type of the context'
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

    learning_outcome = context_model.learning_outcomes.create!(abbreviation: params[:abbreviation], short_description: params[:short_description], full_outcome_description: params[:full_outcome_description])

    if params[:linked_outcome_ids]
      params[:linked_outcome_ids].each do |linked_outcome_id|
        LearningOutcomeLink.create!(source_id: learning_outcome.id, target_id: linked_outcome_id)
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.warn "Failed to link learning outcome #{learning_outcome.id} to learning outcome #{linked_outcome_id}: #{e.message}"
      end
    end

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

    glo = LearningOutcome.create!(context_type: nil, context_id: nil, abbreviation: params[:abbreviation], short_description: params[:short_description], full_outcome_description: params[:full_outcome_description])

    if params[:linked_outcome_ids]
      params[:linked_outcome_ids].each do |linked_outcome_id|
        LearningOutcomeLink.create!(source_id: glo.id, target_id: linked_outcome_id)
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.warn "Failed to link learning outcome #{glo.id} to learning outcome #{linked_outcome_id}: #{e.message}"
      end
    end

    present glo, with: Entities::LearningOutcomeEntity
  end

=begin
  desc 'Update ILO'
  params do
    requires :unit_id, type: Integer, desc: 'The unit ID for which the ILO belongs to'
    optional :name, type: String, desc: 'The ILO''s new name'
    optional :description, type: String, desc: 'The ILO''s new description'
    optional :abbreviation, type: String, desc: 'The ILO''s new abbreviation'
    optional :ilo_number, type: Integer, desc: 'The ILO''s new sequence number'
  end
  put '/units/:unit_id/outcomes/:id' do
    unit = Unit.find(params[:unit_id])
    error!({ error: 'Unable to locate requested unit.' }, 405) if unit.nil?

    unless authorise? current_user, unit, :update
      error!({ error: 'You are not authorised to update outcomes in this unit.' }, 403)
    end

    ilo = unit.learning_outcomes.find(params[:id])
    error!({ error: 'Unable to locate outcome requested.' }, 405) if ilo.nil?

    ilo_parameters = ActionController::Parameters.new(params)
                                                 .permit(
                                                   :name,
                                                   :description,
                                                   :abbreviation
                                                 )
    unit.move_ilo(ilo, params[:ilo_number]) if params[:ilo_number]
    ilo.update!(ilo_parameters)
    present ilo, with: Entities::LearningOutcomeEntity
  end
=end

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

  desc 'Download the outcomes for a specified context (unit, course, task_definition, ect.) to a csv'
  params do
    requires :context_id, type: Integer, desc: 'The id of the context'
  end
  get '/:context_type_plural/:context_id/outcomes/csv' do
    # find context model dynamically
    context_type = params[:context_type_plural].singularize.camelize
    context_model = context_type.classify.constantize.find(params[:context_id])

    unless authorise? current_user, context_model, :update
      error!({ error: 'You are not authorised to download outcomes for this context.' }, 403)
    end

    if context_type == 'Unit'
      title = context_model.code
    elsif context_type == 'Task_Definition'
      title = context_model.abbreviation
    else
      title = "GLOs"
    end
    content_type 'application/octet-stream'
    header['Content-Disposition'] = "attachment; filename=#{title}-LearningOutcomes.csv"
    header['Access-Control-Expose-Headers'] = 'Content-Disposition'
    env['api.format'] = :binary
    context_model.export_learning_outcome_to_csv
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

  desc 'Upload the outcomes for a specified context (unit, course, task_definition, ect.) from a csv'
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
