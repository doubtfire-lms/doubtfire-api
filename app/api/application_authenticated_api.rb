class ApplicationAuthenticatedApi < ApplicationApi
  # Ensure we have access to the current user and ability to test authentication
  helpers AuthenticationHelpers
  # Ensure we have access to the authorisation methods
  helpers AuthorisationHelpers

  # Before any action in the api, ensure that the user is authenticated
  before do
    authenticated?
  end
end
