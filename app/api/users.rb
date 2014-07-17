require 'grape'

module Api
  class Users < Grape::API
    helpers AuthHelpers
    helpers AuthorisationHelpers
    
    before do
      authenticated?
    end

    desc "Get users"
    get '/users' do
      #TODO: authorise!
      @users = User.all
    end

    desc "Get user"
    get '/users/:id' do
      #TODO: authorise!
      @user = User.find(params[:id])
    end

    desc "Get convenors"
    get '/convenors' do
      @user_roles = User.convenors
    end

    desc "Get tutors"
    get '/tutors' do
      @user_roles = User.tutors
    end
    
    desc "Update a user"
    params do
      requires :id, type: Integer, desc: 'The user id to update'
      group :user do
        optional :first_name    , type: String,   desc: 'New first name for user'
        optional :last_name     , type: String,   desc: 'New last name for user'
        optional :email         , type: String,   desc: 'New email address for user'
        optional :username      , type: String,   desc: 'New username for user'
        optional :nickname      , type: String,   desc: 'New nickname for user'
        optional :system_role   , type: String,   desc: 'New role for user [Admin, Convenor, Tutor, Student]'
      end
    end
    put '/users/:id' do
      
      # can only modify if current_user.id is same as :id provided
      # (i.e., user wants to update their own data) or if updateUser token
      if (params[:id] == current_user.id) || (authorise? current_user, User, :updateUser)
        
        user = User.find(params[:id])

        user_parameters = ActionController::Parameters.new(params)
                                            .require(:user)
                                            .permit(
                                              :first_name,
                                              :last_name,
                                              :email,
                                              :username,
                                              :nickname
                                            )

        # have to translate the system_role -> role
        # note we only let user_parameters role if we're actually *changing* the role
        # (i.e., not passing in the *same* role)
        if params[:user][:system_role] && user.role.id != Role.with_name(params[:user][:system_role]).id
          user_parameters[:role] = params[:user][:system_role]
        end
        
        #
        # Only allow change of role if current user has permissions to demote/promote the user to the new role
        #
        if user_parameters[:role]
          # work out if promoting or demoting
          new_role = Role.with_name(user_parameters[:role])
          if new_role.nil?
            error!({"error" => "No such role name #{user_parameters[:role]}"}, 403)
          end
          action = new_role.id > user.role.id ? :promoteUser : :demoteUser
          # current user not authorised to peform action with new role?
          if not authorise? current_user, User, action, new_role
            error!({"error" => "Not authorised to #{action} user with id=#{params[:id]} to #{new_role.name}" }, 403)
          end
          # update :role to actual Role object rather than String type
          user_parameters[:role] = new_role
        end
        
        # Update changes made to user
        user.update!(user_parameters)
        user
      
      else
        error!({"error" => "Cannot modify user with id=#{ params[:id]} - not authorised" }, 403)
      end  
      
    end
    
    desc "Create user"
    params do
      group :user do
        requires :first_name    , type: String,   desc: 'New first name for user'
        requires :last_name     , type: String,   desc: 'New last name for user'
        requires :email         , type: String,   desc: 'New email address for user'
        requires :username      , type: String,   desc: 'New username for user'
        requires :nickname      , type: String,   desc: 'New nickname for user'
        requires :system_role   , type: String,   desc: 'New system role for user [Admin, Convenor, Tutor, Student]'
      end
    end
    post '/users' do
      #
      # Only admins can create users
      #
      if not authorise? current_user, User, :createUser
        error!({"error" => "Not authorised to create new users"}, 403)
      else
        params[:user][:password] = "password"
        user_parameters = ActionController::Parameters.new(params)
                                            .require(:user)
                                            .permit(
                                              :first_name,
                                              :last_name,
                                              :email,
                                              :username,
                                              :nickname,
                                              :password,
                                            )
      
        # have to translate the system_role -> role
        user_parameters[:role] = params[:user][:system_role]
          
        #
        # Give new user their new role
        #
        new_role = Role.with_name(user_parameters[:role])
        if new_role.nil?
          error!({"error" => "No such role name #{val}"}, 403)
        end
        # update :role to actual Role object rather than String type
        user_parameters[:role] = new_role
        
        user = User.create!(user_parameters)
        user
      end
    end
    
    desc "Upload CSV of users"
    params do
      requires :file, type: Rack::Multipart::UploadedFile, :desc => "CSV upload file."
    end
    post '/csv/users' do
      if not authorise? current_user, User, :uploadCSV
        error!({"error" => "Not authorised to upload CSV of users"}, 403)
      end
      
      # Actually import...
      User.import_from_csv(params[:file][:tempfile])
    end
    
    desc "Download CSV of all users"
    get '/csv/users' do
      if not authorise? current_user, User, :downloadCSV
        error!({"error" => "Not authorised to upload CSV of users"}, 403)
      end
      
      content_type "application/octet-stream"
      header['Content-Disposition'] = "attachment; filename=doubtfire_users.csv "
      env['api.format'] = :binary
      User.export_to_csv
      
    end

  end
end
