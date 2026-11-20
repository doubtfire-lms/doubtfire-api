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
    assert_equal username, result['success'].first['row']['ontrack_username']
    assert_equal student.student_id, result['success'].first['row']['ontrack_student_id']
    assert_equal login_id, result['success'].first['row']['ontrack_login_id']
  end

  def test_preview_does_not_link_the_login_id
    unit = FactoryBot.create(:unit, with_students: false)
    student = FactoryBot.create(:user, :student)

    login_id = SecureRandom.uuid
    result = run_job(unit, FakeSource.new([lms_member('10', login_id, student)]), preview_only: true)

    assert_nil student.reload.login_id
    assert_equal student.username, result['success'].first['row']['ontrack_username']
    assert_equal student.student_id, result['success'].first['row']['ontrack_student_id']
    assert_equal login_id, result['success'].first['row']['ontrack_login_id']
  end

  def test_preview_shows_the_account_fields_for_a_new_student
    unit = FactoryBot.create(:unit, with_students: false)
    student = FactoryBot.build(:user, :student)
    login_id = SecureRandom.uuid
    member = lms_member('10', login_id, student)
    member[:student_id] = '12345678'

    result = run_job(unit, FakeSource.new([member]), preview_only: true)

    row = result['success'].first['row']
    assert_equal login_id, row['lms_username']
    assert_equal '12345678', row['lms_student_id']
    assert_equal student.email.split('@').first, row['ontrack_username']
    assert_equal '12345678', row['ontrack_student_id']
    assert_equal login_id, row['ontrack_login_id']
    assert_nil User.find_by(email: student.email)
  end

  def test_import_shows_the_saved_account_fields_for_a_new_student
    unit = FactoryBot.create(:unit, with_students: false)
    student = FactoryBot.build(:user, :student)
    login_id = SecureRandom.uuid
    member = lms_member('10', login_id, student)
    member[:student_id] = '87654321'

    result = run_job(unit, FakeSource.new([member]), preview_only: false)

    user = User.find_by!(email: student.email)
    row = result['success'].first['row']
    assert_equal user.username, row['ontrack_username']
    assert_equal user.student_id, row['ontrack_student_id']
    assert_equal user.login_id, row['ontrack_login_id']
    assert_equal '87654321', row['ontrack_student_id']
  end

  def test_preview_and_import_map_the_lti_person_id_for_a_new_student_when_configured
    unit = FactoryBot.create(:unit, with_students: false)
    student = FactoryBot.build(:user, :student)
    member = lms_member_with_sourced_id('10', SecureRandom.uuid, student, '12345678')

    with_student_id_mapping do
      preview = run_job(unit, FakeSource.new([member]), preview_only: true)

      assert_empty preview['errors']
      assert_nil preview['success'].first['row']['lms_student_id']
      assert_equal '12345678', preview['success'].first['row']['ontrack_student_id']
      assert_nil User.find_by(email: student.email)

      import = run_job(unit, FakeSource.new([member]), preview_only: false)

      assert_empty import['errors']
      assert_equal '12345678', User.find_by!(email: student.email).student_id
      assert_equal '12345678', import['success'].first['row']['ontrack_student_id']
    end
  end

  def test_preview_and_import_fill_a_missing_student_id_for_an_existing_student
    unit = FactoryBot.create(:unit, with_students: false)
    student = FactoryBot.create(:user, :student)
    student.update!(student_id: nil)
    member = lms_member_with_sourced_id('10', SecureRandom.uuid, student, '12345678')

    with_student_id_mapping do
      preview = run_job(unit, FakeSource.new([member]), preview_only: true)

      assert_equal '12345678', preview['success'].first['row']['ontrack_student_id']
      assert_includes preview['success'].first['message'], 'Would set student ID'
      assert_nil student.reload.student_id

      import = run_job(unit, FakeSource.new([member]), preview_only: false)

      assert_empty import['errors']
      assert_equal '12345678', student.reload.student_id
      assert_includes import['success'].first['message'], 'Set student ID'
    end
  end

  def test_import_does_not_claim_another_users_student_id_from_the_lti_person_id
    unit = FactoryBot.create(:unit, with_students: false)
    taken_id = FactoryBot.create(:user, :student).student_id
    student = FactoryBot.build(:user, :student)
    member = lms_member_with_sourced_id('10', SecureRandom.uuid, student, taken_id)

    with_student_id_mapping do
      preview = run_job(unit, FakeSource.new([member]), preview_only: true)
      import = run_job(unit, FakeSource.new([member]), preview_only: false)

      assert_nil preview['success'].first['row']['ontrack_student_id']
      assert_nil import['success'].first['row']['ontrack_student_id']
      assert_nil User.find_by!(email: student.email).student_id
    end
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

  def lms_member_with_sourced_id(id, login_id, user, student_id)
    lms_member(id, login_id, user).tap do |member|
      member[:lis_person_sourcedid] = student_id
      member[:member]['lis_person_sourcedid'] = student_id
    end
  end

  def with_student_id_mapping
    config = Doubtfire::Application.config
    original_settings = config.institution_settings
    mapped_settings = original_settings.dup
    mapped_settings.define_singleton_method(:map_lti_member_to_student_id) { |member| member['lis_person_sourcedid'] }
    config.institution_settings = mapped_settings
    yield
  ensure
    config.institution_settings = original_settings
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
