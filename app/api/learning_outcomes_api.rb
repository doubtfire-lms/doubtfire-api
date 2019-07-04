require 'grape'

module Api
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
      ilo
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
      ilo
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

    desc 'Download the outcomes for a unit to a csv'
    get '/units/:unit_id/outcomes/csv' do
      unit = Unit.find(params[:unit_id])
      error!({ error: 'Unable to locate requested unit.' }, 405) if unit.nil?

      unless authorise? current_user, unit, :update
        error!({ error: 'You are not authorised to download outcomes for this unit.' }, 403)
      end

      content_type 'application/octet-stream'
      header['Content-Disposition'] = "attachment; filename=#{unit.code}-LearningOutcomes.csv "
      env['api.format'] = :binary
      unit.export_learning_outcome_to_csv
    end

    desc 'Upload the outcomes for a unit from a csv'
    params do
      requires :file, type: Rack::Multipart::UploadedFile, desc: 'CSV upload file.'
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
  end
end
