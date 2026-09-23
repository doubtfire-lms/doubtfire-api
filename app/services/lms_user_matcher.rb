# frozen_string_literal: true

#
# Finds OnTrack users for LMS members using the same lookup order as the LTI launch sign in
# (login id, then username, then email), so an imported student is the same account they get
# when they later launch OnTrack from the LMS.
#
module LmsUserMatcher
  module_function

  def user_id_data(login_id:, email:)
    {
      login_id: login_id,
      email: email,
      username: email.to_s[/(.*)@/, 1]
    }
  end

  def find_user(login_id:, email:)
    data = user_id_data(login_id: login_id, email: email)
    (data[:login_id].present? && User.find_by(login_id: data[:login_id])) ||
      (data[:username].present? && User.find_by(username: data[:username])) ||
      (data[:email].present? && User.find_by(email: data[:email])) ||
      nil
  end
end
