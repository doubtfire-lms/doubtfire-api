require 'test_helper'

class LtiCourseDataSourceTest < ActiveSupport::TestCase
  class FakeServer
    def initialize(members, plugin_users)
      @members = members
      @plugin_users = plugin_users
    end

    def link
      { 'courseDataAvailable' => true }
    end

    def members
      { 'members' => @members }
    end

    def course_data(*)
      { 'users' => @plugin_users, 'groups' => [] }
    end
  end

  def test_login_id_comes_from_names_and_roles_or_the_plugin_username
    members = [
      { 'user_id' => '1', 'email' => 'one@example.com', 'ext_user_username' => 'moid-from-nrps', 'roles' => ['Learner'] },
      { 'user_id' => '2', 'email' => 'two@example.com', 'roles' => ['Learner'] }
    ]
    plugin_users = [{ 'id' => 2, 'username' => 'moid-from-plugin', 'enrolments' => [{ 'active' => true }] }]

    source = LtiCourseDataSource.new(FactoryBot.create(:unit, with_students: false))
    source.instance_variable_set(:@server, FakeServer.new(members, plugin_users))

    assert_equal(%w[moid-from-nrps moid-from-plugin], source.members.map { |member| member[:login_id] })
  end
end
