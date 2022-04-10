require 'json/jwt'
require 'onelogin/ruby-saml'

class AuthSamlHelper
    def auth_saml2 (respSAML)
        response = OneLogin::RubySaml::Response.new(respSAML, allowed_clock_drift: 1.second,
                                                                            settings: AuthenticationHelpers.saml_settings)

        # We validate the SAML Response and check if the user already exists in the system
        return error!({ error: 'Invalid SAML response.' }, 401) unless response.is_valid?

        attributes = response.attributes

        login_id = response.name_id || response.nameid
        email = login_id

        logger.info "Authenticate #{email} from #{request.ip}"

        # Lookup using login_id if it exists
        # Lookup using email otherwise and set login_id
        # Otherwise create new
        user = User.find_by(login_id: login_id) ||
                User.find_by_username(email[/(.*)@/, 1]) ||
                User.find_by(email: email) ||
                User.find_or_create_by(login_id: login_id) do |new_user|
                  role_response = attributes.fetch(/role/) || attributes.fetch(/userRole/)
                  role = role_response.include?('Staff') ? Role.tutor.id : Role.student.id
                  first_name = (attributes.fetch(/givenname/) || attributes.fetch(/cn/)).capitalize
                  last_name = attributes.fetch(/surname/).capitalize
                  username = email.split('@').first
                  # Some institutions may provide givenname and surname, others
                  # may only provide common name which we will use as first name
                  new_user.first_name = first_name
                  new_user.last_name  = last_name
                  new_user.email      = email
                  new_user.username   = username
                  new_user.nickname   = first_name
                  new_user.role_id    = role
                end

        # Set login id + username if not yet specified
        user.login_id = login_id if user.login_id.nil?
        user.username = username if user.username.nil?

        # Try and save the user once authenticated if new
        if user.new_record?
          user.encrypted_password = BCrypt::Password.create(SecureRandom.hex(32))
          unless user.valid?
            error!(error: 'There was an error creating your account in Doubtfire. ' \
                          'Please get in contact with your unit convenor or the ' \
                          'Doubtfire administrators.')
          end
          user.save
        end

        # Generate a temporary auth_token for future requests
        onetime_token = user.generate_temporary_authentication_token!

        logger.info "Redirecting #{user.username} from #{request.ip}"

        # Must redirect to the front-end after sign in
        protocol = Rails.env.development? ? 'http' : 'https'
        host = Rails.env.development? ? "#{protocol}://localhost:3000" : Doubtfire::Application.config.institution[:host]
        host = "#{protocol}://#{host}" unless host.starts_with?('http')
        redirect "#{host}/#sign_in?authToken=#{onetime_token.authentication_token}&username=#{user.username}"
    end
end
