require 'test_helper'

class UserIdentityTest < ActiveSupport::TestCase
  # Only ids starting with "moid-" are institution ids, like a Monash UUID check
  class MoidSettings
    def institution_login_id?(login_id)
      login_id.start_with?('moid-')
    end
  end

  def test_login_id_match_wins_over_username_and_email
    login_id = SecureRandom.uuid
    by_login_id = FactoryBot.create(:user, login_id: login_id)
    by_email = FactoryBot.create(:user)

    assert_equal by_login_id, UserIdentity.find_user(login_id: login_id, email: by_email.email)
  end

  def test_falls_back_to_username_then_email
    by_username = FactoryBot.create(:user)
    by_email = FactoryBot.create(:user)

    assert_equal by_username, UserIdentity.find_user(login_id: SecureRandom.uuid, email: 'someone@example.com', username: by_username.username)
    assert_equal by_email, UserIdentity.find_user(login_id: nil, email: by_email.email)
    assert_nil UserIdentity.find_user(login_id: nil, email: 'nobody-at-all@example.com')
  end

  def test_link_identity_fills_an_empty_login_id_without_renaming
    user = FactoryBot.create(:user)
    username = user.username
    first = SecureRandom.uuid

    UserIdentity.link_identity(user, login_id: first, username: 'someone-else')
    assert_equal first, user.reload.login_id
    assert_equal username, user.username

    UserIdentity.link_identity(user, login_id: SecureRandom.uuid)
    assert_equal first, user.reload.login_id
  end

  def test_link_identity_fills_an_empty_username_without_replacing_the_login_id
    login_id = SecureRandom.uuid
    user = FactoryBot.create(:user, login_id: login_id)
    user.update_column(:username, nil) # rubocop:disable Rails/SkipsModelValidations

    UserIdentity.link_identity(user, login_id: SecureRandom.uuid, username: 'filled-username')

    user.reload
    assert_equal 'filled-username', user.username
    assert_equal login_id, user.login_id
  end

  def test_login_ids_the_institution_rejects_are_replaced_and_never_matched
    user = FactoryBot.create(:user, login_id: '153623')

    with_settings(MoidSettings.new) do
      assert_nil UserIdentity.find_user(login_id: '153623', email: 'nobody-at-all@example.com')
      assert_not UserIdentity.mismatch?(user, 'moid-incoming')

      UserIdentity.link_identity(user, login_id: 'moid-incoming')
      assert_equal 'moid-incoming', user.reload.login_id

      UserIdentity.link_identity(user, login_id: 'not-a-moid')
      assert_equal 'moid-incoming', user.reload.login_id
    end
  end

  def test_mismatch_needs_a_different_stored_login_id
    login_id = SecureRandom.uuid
    linked = FactoryBot.create(:user, login_id: login_id)
    unlinked = FactoryBot.create(:user)

    assert UserIdentity.mismatch?(linked, SecureRandom.uuid)
    assert_not UserIdentity.mismatch?(linked, login_id.upcase)
    assert_not UserIdentity.mismatch?(linked, nil)
    assert_not UserIdentity.mismatch?(unlinked, SecureRandom.uuid)
  end

  def test_mismatches_only_block_when_enforced
    user = FactoryBot.create(:user, login_id: SecureRandom.uuid)

    assert_not UserIdentity.blocked?(user, login_id: SecureRandom.uuid, email: user.email, source: 'test')
    with_enforcement do
      assert UserIdentity.blocked?(user, login_id: SecureRandom.uuid, email: user.email, source: 'test')
      assert_not UserIdentity.blocked?(user, login_id: user.login_id, email: 'changed@example.com', source: 'test')
    end
  end

  def test_lti_user_id_data_falls_back_to_the_lti_user_id_without_an_institution_hook
    with_settings(Object.new) do
      data = UserIdentity.lti_user_id_data('user_id' => '42', 'email' => 'student@example.com')

      assert_equal({ login_id: '42', email: 'student@example.com', username: 'student' }, data)
    end
  end

  private

  def with_settings(settings)
    config = Doubtfire::Application.config
    original = config.institution_settings
    config.institution_settings = settings
    yield
  ensure
    config.institution_settings = original
  end

  def with_enforcement
    config = Doubtfire::Application.config
    original = config.enforce_login_id_match
    config.enforce_login_id_match = true
    yield
  ensure
    config.enforce_login_id_match = original
  end
end
