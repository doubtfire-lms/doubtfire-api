#
# Finds or creates a student if not found
#
def find_or_create_student(username)
  user_created = nil
  using_cache = !@user_cache.nil?
  if using_cache && !@user_cache.key?(username)
    profile = {
      first_name: Faker::Name.first_name,
      last_name: Faker::Name.last_name,
      nickname: username,
      role_id: Role.student_id,
      email: "#{username}@doubtfire.com",
      username: username
    }
    unless AuthenticationHelpers.aaf_auth?
      profile[:password] = 'password'
      profile[:password_confirmation] = 'password'
    end
    user_created = User.create!(profile)
    @user_cache[username] = user_created if using_cache
  else
    user_created = User.find_by(username: username)
  end
  user_created || @user_cache[username]
end
