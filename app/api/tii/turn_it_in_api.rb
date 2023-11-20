require 'grape'

module Tii
  class TurnItInApi < Grape::API
    helpers AuthenticationHelpers
    helpers AuthorisationHelpers
    include LogHelper

    desc 'Get the current EULA html'
    get 'tii_eula' do
      content_type 'text/html;charset=UTF-8'
      TurnItIn.eula_html
    end

    desc 'Accept the TurnItIn EULA'
    params do
      requires :id, type: Integer, desc: 'The user id who is accepting the EULA'
    end
    put 'tii_eula/users/:id/accept' do
      if current_user.id != params[:id]
        error!({ error: "You are not authorised to accept the EULA on behalf of another user" }, 403)
      end

      present current_user.accept_tii_eula, Grape::Presenters::Presenter
    end
  end
end
