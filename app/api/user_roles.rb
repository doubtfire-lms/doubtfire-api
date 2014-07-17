require 'grape'

module Api
  class UserRoles < Grape::API
    helpers AuthHelpers

    before do
      authenticated?
    end

    desc "Get user roles"
    get '/user_roles' do
      @user_roles = UnitRole.all
    end

    desc "Get convenor users"
    get '/convenors' do
      @user_roles = User.where("system_role = 'convenor' OR system_role = 'admin'")
    end

    desc "Get tutors"
    get '/tutors' do
      @user_roles = UnitRole.tutors
    end
  end
end
