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
    get '/users/:id' do
      #TODO: authorise!
      @user = User.find(params[:id])
    end

    desc "Get convenors"
    get '/users/convenors' do
      @user_roles = User.convenors
    end

    desc "Get tutors"
    get '/users/tutors' do
      @user_roles = User.tutors
    end
  end
end
