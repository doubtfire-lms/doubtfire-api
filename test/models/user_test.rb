require 'test_helper'

class UserTest < ActiveSupport::TestCase
  setup do
    @user = User.first
  end

  test 'user authentication post' do
    assert      @user.authenticate? 'password'
    assert_not  @user.authenticate? 'potato'
  end

  test 'create user' do
    profile = {
      first_name: 'Test',
      last_name: 'Test',
      nickname: 'Test',
      role_id: 1,
      email: 'test@test.org',
      username: 'metoo',
      password: 'password',
      password_confirmation: 'password'
    }
    User.create!(profile)
    assert User.last, profile
  end

  def test_user_is_valid
    user = FactoryBot.create(:user)
    assert user.valid?
  end

  def test_invalid_without_first_name
    user = FactoryBot.build(:user, first_name: nil)
    refute user.valid?
  end

  def test_invalid_without_last_name
    user = FactoryBot.build(:user, last_name: nil)
    refute user.valid?
  end

  test 'profile names allow hyphens and parentheses' do
    user = FactoryBot.build(:user, first_name: 'Mary-Jane', last_name: 'Smith (Jones)', nickname: 'MJ (Student)')

    assert user.valid?
  end

  test 'profile name fields reject hash characters' do
    {
      first_name: 'First#Name',
      last_name: 'Last#Name',
      nickname: 'Preferred#Name'
    }.each do |attribute, value|
      user = FactoryBot.build(:user, attribute => value)

      assert_not user.valid?, attribute
      assert_includes user.errors[attribute], 'contains unsupported characters'
    end
  end

  test 'profile names reject spreadsheet formulas and unsupported punctuation' do
    ['=2+2', '+SUM(A1:A2)', '@command', 'Name=Value', 'Name+Value', 'Name@Value'].each do |value|
      user = FactoryBot.build(:user, first_name: value)

      assert_not user.valid?, value
      assert_includes user.errors[:first_name], 'contains unsupported characters'
    end
  end

  test 'CSV formula escaping neutralises spreadsheet control prefixes' do
    ['=2+2', '+SUM(A1:A2)', '-1+2', '@command', "\tcommand", "\rcommand", "\ncommand"].each do |value|
      assert_equal "'#{value}", CsvHelper.escape_spreadsheet_formula(value)
    end

    assert_equal 'Mary-Jane', CsvHelper.escape_spreadsheet_formula('Mary-Jane')
  end

  test 'system user export neutralises formulas from existing data' do
    @user.first_name = '=2+2'
    @user.save!(validate: false)

    entry = CSV.parse(User.export_to_csv, headers: true).find { |row| row['username'] == @user.username }

    assert_equal "'=2+2", entry['first_name']
  end

  def test_can_create_multiple_auth_tokens
    user = FactoryBot.create(:user)
    t1 = user.generate_authentication_token!
    t2 = user.generate_authentication_token!
    assert_not_equal t1, t2
  end
end
