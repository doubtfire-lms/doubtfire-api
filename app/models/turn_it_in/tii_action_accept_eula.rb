# freeze_string_literal: true

# Accept the turn it in end user license agreement for a user
class TiiActionAcceptEula < TiiAction
  def user
    entity
  end

  def description
    "Accept Turnitin EULA for user #{user.name}"
  end

  def run
    # Skip if the user has already accepted the eula
    if user.tii_eula_version_confirmed && user.tii_eula_version == TurnItIn.eula_version
      self.complete = true
      return
    end

    error_codes = [
      { code: 404, message: 'EULA version was not found' }
    ]

    exec_tca_call "accept eula for user #{user.id}", error_codes do
      body = TCAClient::EulaAcceptRequest.new(
        user_id: user.username,
        language: 'en-us',
        accepted_timestamp: user.tii_eula_date || DateTime.now,
        version: user.tii_eula_version || TurnItIn.eula_version
      )

      if body.version.nil?
        save_and_log_custom_error "TII eula version is nil, user #{id} cannot accept eula"
        return
      end

      # Accepts a particular EULA version on behalf of an external user
      TCAClient::EULAApi.new.eula_version_id_accept_post(
        TurnItIn.x_turnitin_integration_name,
        TurnItIn.x_turnitin_integration_version,
        body.version,
        body
      )

      # Record the version of the eula that was accepted, and that we have confirmed it with tii
      user.confirm_eula_version(body.version, body.accepted_timestamp)

      self.complete = true
      save
    end
  end
end
