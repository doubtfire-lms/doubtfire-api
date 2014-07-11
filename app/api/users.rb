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
        optional :first_name , type: String,  desc: 'New first name for user'
        optional :last_name  , type: String,  desc: 'New last name for user'
        optional :email      , type: String,  desc: 'New email address for user'
        optional :username   , type: String,  desc: 'New username for user'
        optional :nickname   , type: String,  desc: 'New nickname for user'
        optional :system_role, type: String,  desc: 'New system role for user [Admin, Convenor, Tutor, Student]'
      end
    end
    put '/user/:id' do
      #TODO: authorise!
      
      #
      # Permissions need to be authorised based off the current user's role
      #
      permissions = {
      # - admins can modify anyone (super user)
        :admin    => [:promote_admin, :demote_admin, :promote_convenor, :demote_convenor, :promote_tutor, :demote_tutor],
      # - convenors can promote students to tutors
      # - convenors can promote tutors to convenors
      # - convenors cannot demote convenors
      # - convenors can demote tutors
        :convenor => [:promote_convenor, :promote_tutor, :demote_tutor],
      # - tutors have no permissions
      # - students have no permissions
        :tutor    => [],
        :student  => []
      }
      
      # if not an admin, then can only modify if current_user.id is same as :id provided...
      if params[:id] == current_user.id || current_user.has_admin_capability?
        
        user = User.find(params[:id])
        
        params[:user].each do | key, val |
          # update standard key value pairs
          if key != :system_role && key != :id && user[key]
            user[key] = val
          # update permission changes
          end
          #if key == :system_role
          #  switch params[:user][:system_role]
          #end
        end
        
        # Update changes made to user
        user.save!(validate: true)
        user
      
      else
        error!({"error" => "Cannot modify user with id=#{ params[:id]} - not authorised" }, 403)
      end
      
      #
      # If admin, cannot demote your self..
#       current_user_role = current_user.role.name # Admin | Convenor | Tutor | Student
#       :first_name? && user.first_name 
      
      
      
    end
  end
end
