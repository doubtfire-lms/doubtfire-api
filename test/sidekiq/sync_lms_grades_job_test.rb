require 'test_helper'
require 'minitest/mock'

class SyncLmsGradesJobTest < ActiveSupport::TestCase
  class FakeSource
    attr_reader :members

    def initialize(members)
      @members = members
    end
  end

  def test_preview_reports_matches_without_sending_scores
    unit = FactoryBot.create(:unit, with_students: false)
    matched = FactoryBot.create(:user, :student)
    unmatched_in_ontrack = FactoryBot.create(:user, :student)
    unit.enrol_student(matched, Campus.first).update!(grade: 2)
    unit.enrol_student(unmatched_in_ontrack, Campus.first).update!(grade: 1)

    source = FakeSource.new([
                              lms_member('10', matched.login_id, matched.email),
                              lms_member('11', 'nobody', 'nobody@example.com')
                            ])

    result = run_job(unit, source, preview_only: true)

    assert_equal 1, result['success'].length
    assert_equal '10', result['success'].first['row']['lms_user_id']
    assert_equal matched.username, result['success'].first['row']['ontrack_username']
    assert_equal 'Will send: 2%', result['success'].first['message']
    assert_equal(['No matching OnTrack user', 'Not a student in the LMS course'], result['ignored'].map { |row| row['message'] })
    assert_equal unmatched_in_ontrack.username, result['ignored'].last['row']['ontrack_username']
    assert_empty result['errors']
  end

  def test_ungraded_students_are_skipped_by_default
    unit = FactoryBot.create(:unit, with_students: false)
    student = FactoryBot.create(:user, :student)
    unit.enrol_student(student, Campus.first).update!(grade: 0)

    result = run_job(unit, FakeSource.new([lms_member('10', student.login_id, student.email)]), preview_only: true)

    assert_empty result['success']
    assert_equal(['Not graded yet'], result['ignored'].map { |row| row['message'] })
  end

  def test_grades_of_zero_are_sent_when_skipping_is_off
    unit = FactoryBot.create(:unit, with_students: false)
    unit.create_lms_integration!(skip_ungraded: false)
    student = FactoryBot.create(:user, :student)
    unit.enrol_student(student, Campus.first).update!(grade: 0)

    result = run_job(unit, FakeSource.new([lms_member('10', student.login_id, student.email)]), preview_only: true)

    assert_equal(['Will send: 0%'], result['success'].map { |row| row['message'] })
  end

  def test_grade_rationale_is_sent_as_feedback_when_enabled
    unit = FactoryBot.create(:unit, with_students: false)
    unit.create_lms_integration!(send_grade_rationale: true)
    student = FactoryBot.create(:user, :student)
    unit.enrol_student(student, Campus.first).update!(grade: 85, grade_rationale: 'Strong portfolio')
    submit = stub_request(:post, "http://lti.test/lti/api/internal/units/#{unit.id}/scores")
             .with(body: { scores: [{ userId: '10', scoreGiven: 85, comment: 'Strong portfolio' }] }.to_json)
             .to_return(status: 200, body: { results: [{ userId: '10', success: true }] }.to_json,
                        headers: { 'Content-Type' => 'application/json' })

    with_lti_service do
      result = run_job(unit, FakeSource.new([lms_member('10', student.login_id, student.email)]), preview_only: false)
      assert_equal 'Strong portfolio', result['success'].first['row']['feedback']
    end
    assert_requested submit
  end

  private

  def with_lti_service
    config = Doubtfire::Application.config
    original = [config.lti_internal_url, config.lti_internal_key]
    config.lti_internal_url = 'http://lti.test'
    config.lti_internal_key = 'internal-test-key'
    yield
  ensure
    config.lti_internal_url, config.lti_internal_key = original
  end

  def lms_member(id, login_id, email)
    member = { 'user_id' => id, 'roles' => ['Learner'] }
    { lms_user_id: id, login_id: login_id, email: email, name: 'LMS Student', member: member }
  end

  # Webmock rejects any request, so a preview that tried to submit scores would fail here
  def run_job(unit, source, preview_only:)
    job = SyncLmsGradesJob.new
    stored = {}
    job.define_singleton_method(:total) { |_| nil }
    job.define_singleton_method(:at) { |*_| nil }
    job.define_singleton_method(:store) { |data| stored.merge!(data) }
    LmsIntegration.stub(:data_source_for, source) { job.perform(unit.id, preview_only) }
    JSON.parse(stored[:result])
  end
end
