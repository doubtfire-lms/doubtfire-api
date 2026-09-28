require 'test_helper'
require 'minitest/mock'

class ImportLmsStudentsJobTest < ActiveSupport::TestCase
  class FakeSource
    attr_reader :members

    def initialize(members)
      @members = members
    end
  end

  def test_import_links_the_lms_login_id_to_an_existing_student
    unit = FactoryBot.create(:unit, with_students: false)
    student = FactoryBot.create(:user, :student)
    username = student.username
    login_id = SecureRandom.uuid

    result = run_job(unit, FakeSource.new([lms_member('10', login_id, student)]), preview_only: false)

    assert_empty result['errors']
    assert_equal login_id, student.reload.login_id
    assert_equal username, student.username
    assert unit.projects.find_by(user_id: student.id).enrolled
  end

  def test_preview_does_not_link_the_login_id
    unit = FactoryBot.create(:unit, with_students: false)
    student = FactoryBot.create(:user, :student)

    run_job(unit, FakeSource.new([lms_member('10', SecureRandom.uuid, student)]), preview_only: true)

    assert_nil student.reload.login_id
  end

  def test_student_linked_to_a_different_login_id_is_not_imported_when_enforced
    unit = FactoryBot.create(:unit, with_students: false)
    student = FactoryBot.create(:user, :student, login_id: SecureRandom.uuid)
    config = Doubtfire::Application.config
    config.enforce_login_id_match = true

    result = run_job(unit, FakeSource.new([lms_member('10', SecureRandom.uuid, student)]), preview_only: false)

    assert_equal(["#{student.username} is linked to a different login id"], result['errors'].map { |row| row['message'] })
    assert_nil unit.projects.find_by(user_id: student.id)
  ensure
    config.enforce_login_id_match = false
  end

  private

  def lms_member(id, login_id, user)
    member = {
      'user_id' => id,
      'email' => user.email,
      'name' => user.name,
      'given_name' => user.first_name,
      'family_name' => user.last_name,
      'roles' => ['Learner']
    }
    {
      lms_user_id: id,
      login_id: login_id,
      email: user.email,
      name: user.name,
      first_name: user.first_name,
      last_name: user.last_name,
      roles: member['roles'],
      active: true,
      group_ids: [],
      member: member
    }
  end

  def run_job(unit, source, preview_only:)
    job = ImportLmsStudentsJob.new
    stored = {}
    job.define_singleton_method(:total) { |_| nil }
    job.define_singleton_method(:at) { |*_| nil }
    job.define_singleton_method(:store) { |data| stored.merge!(data) }
    LmsIntegration.stub(:data_source_for, source) { job.perform(unit.id, preview_only, false, false) }
    JSON.parse(stored[:result])
  end
end
