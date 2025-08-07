require 'grape'

class LtiApi < Grape::API
  helpers AuthenticationHelpers
  helpers AuthorisationHelpers
  helpers LtiHelper
  include LogHelper

  # before do
  #   authenticated?
  # end

  desc 'Check if current user is allowed to deeplink this data'
  params do
    optional :ltik, type: String, desc: 'LtiKey provided with user info and deeplink resources'
  end
  get '/lti/deeplink' do
    authenticated?

    unless authorise? current_user, User, :convene_units
      error!({ error: "Not authorised to deeplink this unit." }, 403)
    end

    token = decode_lti_token(params[:ltik])

    unit_id = token.dig("deeplinkRequest", "unit_id")
    if unit_id.nil?
      error!({ error: 'Invalid LTI token.' }, 401)
    end

    unit = Unit.find_by(code: unit_id)

    if unit.nil?
      error!({ error: 'Unit does not exist' }, 404)
    end

    unless authorise? current_user, unit, :enrol_student
      error!({ error: "Not authorised to deeplink this unit." }, 403)
    end

    status 200
  end
end
