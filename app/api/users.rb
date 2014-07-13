require 'grape'

module Api
  class Users < Grape::API
    helpers AuthHelpers

    before do
      authenticated?
    end

    desc "Get users"
    get '/users' do
      #TODO: authorise!
      @users = User.all
    end

    desc "Get user"
    get '/user/:id' do
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
        optional :system_role_id, type: Integer,  desc: 'New system role for user [4 = Admin, 3 = Convenor, 2 = Tutor, 1 = Student]'
      end
    end
    put '/user/:id' do
      #TODO: authorise!
      
      #
      # Permissions need to be authorised based off the current user's role
      #
      permissions = {
      # - admins can modify anyone (super user)
        Role.admin    => { :promote => [ Role.admin.id, Role.convenor.id, Role.tutor.id, Role.student.id ],
                           :demote  => [ Role.admin.id, Role.convenor.id, Role.tutor.id, Role.student.id ]  },

      # - convenors can promote students to tutors
      # - convenors can promote tutors to convenors
      # - convenors cannot demote convenors
      # - convenors can demote tutors
        Role.convenor => { :promote => [ Role.convenor.id, Role.tutor.id ],
                           :demote  => [ Role.tutor.id ] },
      # - tutors have no permissions
      # - students have no permissions
        Role.tutor    => { :promote => [], :demote => [] },
        Role.student  => { :promote => [], :demote => [] }
      }
      
      # if not an admin, then can only modify if current_user.id is same as :id provided...
      if params[:id] == current_user.id || current_user.has_admin_capability?
        
        user = User.find(params[:id])
        
        params[:user].each do | key, val |
          puts key
          # update standard key value pairs
          if key != 'system_role_id' && key != 'id' && user[key]
            user[key] = val
          # update permission changes
          elsif key == 'system_role_id'
            # work out if promoting or demoting
            isPromoting = val > user.role.id
            # do the permissions allow the current user's role to promote or demote the user to the given role?
            if permissions[current_user.role][isPromoting ? :promote : :demote].include?(val)
              user.role = Role.find(val)
            else
              error!({"error" => "Not authorised to #{isPromoting ? "promote" : "demote"} user with id=#{params[:id]} to level #{val}" }, 403)
            end
          end
        end
        
        # Update changes made to user
        user.save!(validate: true)
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
        requires :system_role_id, type: Integer,  desc: 'New system role for user [4 = Admin, 3 = Convenor, 2 = Tutor, 1 = Student'
      end
    end
    post '/user' do
      #
      # Only admins can create users
      #
      if current_user.role != Role.admin
        error!({"error" => "Not authorised to create new users"}, 403)
      end
      
      #TODO: fix default password!
      params[:user][:password] = "password"
      user_parameters = ActionController::Parameters.new(params)
                                          .require(:user)
                                          .permit(
                                            :first_name,
                                            :last_name,
                                            :email,
                                            :username,
                                            :nickname,
                                            :password
                                          )
      user = User.create!(user_parameters)
      
      #
      # Give new user their new role
      #
      user.role = Role.find(params[:user][:system_role_id])
              
      user
    end

  end
end
