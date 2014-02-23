require 'grape'

module Api
  class UserRoles < Grape::API
    helpers AuthHelpers

    before do
      authenticated?
    end

    desc "Get user roles"
    get '/user_roles' do
      @user_roles = UserRole.all
    end

    desc "Get convenors"
    get '/convenors' do
      @user_roles = UserRole.convenors
    end

    desc "Get tutors"
    get '/tutors' do
      @user_roles = UserRole.tutors
    end
  end
end
