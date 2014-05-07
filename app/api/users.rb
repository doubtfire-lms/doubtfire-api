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
  end
end
