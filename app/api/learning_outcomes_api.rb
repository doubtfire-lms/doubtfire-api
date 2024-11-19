require 'grape'

class LearningOutcomesApi < Grape::API
  helpers AuthenticationHelpers
  helpers AuthorisationHelpers
  helpers MimeCheckHelpers

  before do
    authenticated?
  end

  desc 'Add an outcome to a unit'
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

  desc "Add an outcome to a specified context (unit, course, task, ect.)"
  params do
    requires :context_id, type: Integer, desc: 'The id of the context'
    requires :context_string, type: String, values: ['unit', 'course', 'task'], desc: 'The type of the context'
    requires :name, type: String, desc: 'The ILO''s name'
    requires :description, type: String, desc: 'The ILO''s description'
    optional :abbreviation, type: String, desc: 'The ILO''s new abbreviation'
  end
  post '/:context_string/:context_id/outcomes' do
    # find context model dynamically
    context_model = params[:context_string].classify.constantize.find(id: params[:context_id])

    unless authorise? current_user, context_model, :update
      error!({ error: 'You are not authorised to create outcomes in this context.' }, 403)
    end

    ilo = context_model.add_ilo(params[:name], params[:description], params[:abbreviation]) # need to check if this is implemented across the other models
    present ilo, with: Entities::LearningOutcomeEntity
  end

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

  desc 'Update an outcome in a specified context (unit, course, task, ect.)'
  params do
    requires :context_id, type: Integer, desc: 'The id of the context'
    requires :context_string, type: String, values: ['unit', 'course', 'task'], desc: 'The type of the context'
    optional :name, type: String, desc: 'The ILO''s new name'
    optional :description, type: String, desc: 'The ILO''s new description'
    optional :abbreviation, type: String, desc: 'The ILO''s new abbreviation'
    optional :ilo_number, type: Integer, desc: 'The ILO''s new sequence number'
  end
  put '/:context_string/:context_id/outcomes/:id' do
    # find context model dynamically
    context_model = params[:context_string].classify.constantize.find(id: params[:context_id])

    unless authorise? current_user, context_model, :update
      error!({ error: 'You are not authorised to update outcomes in this context.' }, 403)
    end

    ilo = context_model.learning_outcomes.find(params[:id])
    error!({ error: 'Unable to locate outcome requested.' }, 405) if ilo.nil?

    ilo_parameters = ActionController::Parameters.new(params)
                                                 .permit(
                                                   :name,
                                                   :description,
                                                   :abbreviation
                                                 )
    context_model.move_ilo(ilo, params[:ilo_number]) if params[:ilo_number]
    ilo.update!(ilo_parameters)
    present ilo, with: Entities::LearningOutcomeEntity
  end

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

  desc 'Delete an outcome from a specified context (unit, course, task, ect.)'
  params do
    requires :context_id, type: Integer, desc: 'The id of the context'
    requires :context_string, type: String, values: ['unit', 'course', 'task'], desc: 'The type of the context'
    requires :id, type: Integer, desc: 'The id for the outcome you wish to delete'
  end
  delete '/:context_string/:context_id/outcomes/:id' do
    # find context model dynamically
    context_model = params[:context_string].classify.constantize.find(id: params[:context_id])

    unless authorise? current_user, context_model, :update
      error!({ error: 'You are not authorised to delete outcomes in this context.' }, 403)
    end

    ilo = context_model.learning_outcomes.find(params[:id])
    error!({ error: 'Unable to locate outcome requested.' }, 405) if ilo.nil?

    ilo.destroy
    nil
  end

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

  desc 'Download the outcomes for a specified context (unit, course, task, ect.) to a csv'
  params do
    requires :context_id, type: Integer, desc: 'The id of the context'
    requires :context_string, type: String, values: ['unit', 'course', 'task'], desc: 'The type of the context'
  end
  get '/:context_string/:context_id/outcomes/csv' do
    # find context model dynamically
    context_model = params[:context_string].classify.constantize.find(id: params[:context_id])

    unless authorise? current_user, context_model, :update
      error!({ error: 'You are not authorised to download outcomes for this context.' }, 403)
    end

    content_type 'application/octet-stream'
    header['Content-Disposition'] = "attachment; filename=#{context_model.code}-LearningOutcomes.csv"
    header['Access-Control-Expose-Headers'] = 'Content-Disposition'
    env['api.format'] = :binary
    context_model.export_learning_outcome_to_csv
  end

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

  desc 'Upload the outcomes for a specified context (unit, course, task, ect.) from a csv'
  params do
    requires :file, type: File, desc: 'CSV upload file.'
    requires :context_id, type: Integer, desc: 'The id of the context'
    requires :context_string, type: String, values: ['unit', 'course', 'task'], desc: 'The type of the context'
  end
  post '/:context_string/:context_id/outcomes/csv' do
    # check mime is correct before uploading
    ensure_csv!(params[:file][:tempfile])

    # find context model dynamically
    context_model = params[:context_string].classify.constantize.find(id: params[:context_id])

    unless authorise? current_user, context_model, :upload_csv
      error!({ error: 'Not authorised to upload CSV of outcomes' }, 403)
    end

    # Actually import...
    context_model.import_outcomes_from_csv(params[:file][:tempfile])
  end
end
