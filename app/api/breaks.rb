require 'grape'

module Api
  class Breaks < Grape::API
    helpers AuthenticationHelpers
    helpers AuthorisationHelpers

    before do
      authenticated?
    end
  end
end