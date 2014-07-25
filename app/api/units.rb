require 'grape'
require 'unit_serializer'

module Api
  class Units < Grape::API
    helpers AuthHelpers
    helpers AuthorisationHelpers

    before do
      authenticated?

      if params[:unit]
        if params[:unit][:start_date].present? && params[:unit][:end_date].present?
          start_date  = DateTime.parse(params[:unit][:start_date])
          end_date    = DateTime.parse(params[:unit][:end_date])

          params[:unit][:start_date]  = start_date
          params[:unit][:end_date]    = end_date
        end
      end
    end

    desc "Get units related to the current user"
    params do
      optional :include_in_active, type: Boolean, desc: 'Include units that are not active'
    end
    get '/units' do
      # gets only the units the current user can "see"
      units = Unit.for_user current_user

      if not params[:include_in_active]
        units = units.where("active = true")
      end

      ActiveModel::ArraySerializer.new(units, each_serializer: ShallowUnitSerializer)
    end

    desc "Get a unit's details"
    get '/units/:id' do
      unit = Unit.find(params[:id])
      if not ((authorise? current_user, unit, :get_unit) or (authorise? current_user, User, :admin_units))
        error!({"error" => "Couldn't find Unit with id=#{params[:id]}" }, 403)
      end

      unit
    end


    desc "Update unit"
    params do
      requires :id, type: Integer, desc: 'The unit id to update'
      group :unit do
        optional :name
        optional :code
        optional :description
        optional :start_date
        optional :end_date
      end
    end
    put '/units/:id' do 
      unit= Unit.find(params[:id])
      
      if not authorise? current_user, unit, :update
        error!({"error" => "Not authorised to update a unit" }, 403)
      end
      
      unit_parameters = ActionController::Parameters.new(params)
      .require(:unit)
      .permit(:name,
              :code,
              :description,
              :start_date, 
              :end_date
             )

      unit.update!(unit_parameters)
      unit_parameters
    end 


    desc "Create unit"
    params do
      group :unit do
        requires :name
        requires :code
        requires :description
        requires :start_date
        requires :end_date
      end
    end
    post '/units' do
      if not authorise? current_user, User, :create_unit
        error!({"error" => "Not authorised to create a unit" }, 403)
      end
      
      unit_parameters = ActionController::Parameters.new(params)
                                          .require(:unit)
                                          .permit(
                                            :name,
                                            :code,
                                            :description,
                                            :start_date,
                                            :end_date
                                          )
      unit = Unit.create!(unit_parameters)

      # Employ current user as convenor
      unit.employ_staff(current_user, Role.convenor)
      unit
    end

    desc "Upload CSV of all the students in a unit"
    params do
      requires :file, type: Rack::Multipart::UploadedFile, :desc => "CSV upload file."
    end
    post '/csv/units/:id' do
      unit= Unit.find(params[:id])
      if not authorise? current_user, unit, :uploadCSV
        error!({"error" => "Not authorised to upload CSV of users"}, 403)
      end
      
      # check mime is correct before uploading
      if not params[:file][:type] == "text/csv"
        error!({"error" => "File given is not a CSV file"}, 403)
      end
      
      # Actually import...
      unit.import_users_from_csv(params[:file][:tempfile])
    end
    
    desc "Download CSV of all users"
    get '/csv/units/:id' do
      unit = Unit.find(params[:id])
      if not authorise? current_user, unit, :downloadCSV
        error!({"error" => "Not authorised to download CSV of users"}, 403)
      end
      
      content_type "application/octet-stream"
      header['Content-Disposition'] = "attachment; filename=doubtfire_users.csv "
      env['api.format'] = :binary
      unit.export_users_to_csv
    end
  end
end
