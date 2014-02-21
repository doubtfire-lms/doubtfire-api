require 'grape'

module Api
  class Users < Grape::API
    helpers AuthHelpers

    before do
      authenticated?
    end

    desc "Get users"
    get '/users' do
      @users = User.all
    end

    desc "Get user"
    get '/user/:id' do
      @user = User.find(params[:id])
    end
  end
end
