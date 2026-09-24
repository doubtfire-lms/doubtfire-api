# frozen_string_literal: true

#
# Finds OnTrack users by their institution login id, then username, then email. SAML sign in,
# LTI launches and LMS imports all share this lookup so a person always resolves to the same account.
#
module UserIdentity
  module_function

  def user_id_data(login_id:, email:)
    {
      login_id: login_id.presence,
      email: email,
      username: email.to_s[/(.*)@/, 1]
    }
  end

  # Institution settings decide which LTI member field holds the institution login id
  def lti_user_id_data(member)
    settings = Doubtfire::Application.config.institution_settings
    return settings.map_lti_member_to_user_id(member) if settings.respond_to?(:map_lti_member_to_user_id)

    user_id_data(login_id: member['ext_user_username'].presence || member['user_id'], email: member['email'])
  end

  def find_user(login_id:, email:, username: nil)
    username ||= email.to_s[/(.*)@/, 1]
    (login_id.present? && User.find_by(login_id: login_id)) ||
      (username.present? && User.find_by(username: username)) ||
      (email.present? && User.find_by(email: email)) ||
      nil
  end

  # Fills in a missing login id or username on a matched account, never replacing either
  def link_identity(user, login_id:, username: nil)
    missing = { login_id: login_id, username: username }.select { |field, value| value.present? && user[field].blank? }
    user.update(missing) if missing.any?
  end
end
