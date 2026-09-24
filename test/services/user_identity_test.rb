require 'test_helper'

class UserIdentityTest < ActiveSupport::TestCase
  def test_login_id_match_wins_over_username_and_email
    by_login_id = FactoryBot.create(:user, login_id: 'moid-login-id-wins')
    by_email = FactoryBot.create(:user)

    assert_equal by_login_id, UserIdentity.find_user(login_id: 'moid-login-id-wins', email: by_email.email)
  end

  def test_falls_back_to_username_then_email
    by_username = FactoryBot.create(:user)
    by_email = FactoryBot.create(:user)

    assert_equal by_username, UserIdentity.find_user(login_id: 'unknown-moid', email: 'someone@example.com', username: by_username.username)
    assert_equal by_email, UserIdentity.find_user(login_id: nil, email: by_email.email)
    assert_nil UserIdentity.find_user(login_id: nil, email: 'nobody-at-all@example.com')
  end

  def test_link_identity_fills_an_empty_login_id_without_renaming
    user = FactoryBot.create(:user)
    username = user.username

    UserIdentity.link_identity(user, login_id: 'moid-first-link', username: 'someone-else')
    assert_equal 'moid-first-link', user.reload.login_id
    assert_equal username, user.username

    UserIdentity.link_identity(user, login_id: 'moid-second-link')
    assert_equal 'moid-first-link', user.reload.login_id
  end

  def test_link_identity_fills_an_empty_username_without_replacing_the_login_id
    user = FactoryBot.create(:user, login_id: 'moid-kept')
    user.update_column(:username, nil) # rubocop:disable Rails/SkipsModelValidations

    UserIdentity.link_identity(user, login_id: 'moid-incoming', username: 'filled-username')

    user.reload
    assert_equal 'filled-username', user.username
    assert_equal 'moid-kept', user.login_id
  end

  def test_lti_user_id_data_falls_back_to_the_lti_user_id_without_an_institution_hook
    config = Doubtfire::Application.config
    original = config.institution_settings
    config.institution_settings = Object.new

    data = UserIdentity.lti_user_id_data('user_id' => '42', 'email' => 'student@example.com')

    assert_equal({ login_id: '42', email: 'student@example.com', username: 'student' }, data)
  ensure
    config.institution_settings = original
  end
end
