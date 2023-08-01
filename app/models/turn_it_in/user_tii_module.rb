# freeze_string_literal: true

# Provides Turnitin integration functionality for User
module UserTiiModule
  # Accept the turn it in eula
  #
  # @param [String] eula_version The version of the eula that was accepted
  def accept_tii_eula(eula_version = TurnItIn.eula_version)
    update(
      tii_eula_version_confirmed: false,
      tii_eula_date: DateTime.now,
      tii_eula_version: eula_version
    )

    TiiActionAcceptEula.find_or_create_by(
      entity: self
    ).perform_async
  end

  def accepted_tii_eula?
    return false unless Doubtfire::Application.config.tii_enabled
    return true unless TiiActionFetchFeaturesEnabled.eula_required?

    tii_eula_version == TurnItIn.eula_version
  end

  def confirm_eula_version(version, timestamp)
    update(
      tii_eula_version_confirmed: true,
      tii_eula_version: version,
      tii_eula_date: timestamp
    )
  end
end
