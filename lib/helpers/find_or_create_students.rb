#
# Finds or creates a student if not found
#
def find_or_create_student(username)
  user_created = nil
  using_cache = !!@user_cache
  if not using_cache or not @user_cache.has_key?(username)
    profile = {
      first_name:             Faker::Name.first_name,
      last_name:              Faker::Name.last_name,
      nickname:               username,
      role_id:                Role.student_id,
      email:                  "#{username}@doubtfire.com",
      username:               username,
      password:               'password',
      password_confirmation:  'password'
    }
    user_created = User.create!(profile)
    @user_cache[username] = user_created if using_cache
  end
  user_created || @user_cache[username]
end
