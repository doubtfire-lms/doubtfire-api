require 'test_helper'
require 'date'
require './lib/helpers/database_populator'

class StaffNotesApiTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper
  include TestHelpers::TestFileHelper

  def app
    Rails.application
  end

  def test_tutor_can_get_staff_notes
    unit = FactoryBot.create(:unit, code: 'COS10001')

    student = FactoryBot.create(:user, :student)
    student_project = unit.enrol_student(student, nil)

    tutor = FactoryBot.create(:user, :tutor)
    unit.employ_staff(tutor, Role.tutor)

    staff_note = StaffNote.create!({
                                     note: "Test note!",
                                     project: student_project,
                                     user: tutor
                                   })

    add_auth_header_for(user: tutor)

    get "/api/projects/#{student_project.id}/staff_notes"
    assert_equal 200, last_response.status

    json = JSON.parse(last_response.body)
    assert json.is_a?(Array), "Response is not an array"
    assert_equal 1, json.size
    assert_equal staff_note.id, json.first['id']
    assert_equal staff_note.note, json.first['note']
    assert_equal tutor.id, json.first['user_id']
  end

  def test_tutor_can_create_staff_notes
    unit = FactoryBot.create(:unit, code: 'COS10001')

    student = FactoryBot.create(:user, :student)
    student_project = unit.enrol_student(student, nil)

    tutor = FactoryBot.create(:user, :tutor)
    unit.employ_staff(tutor, Role.tutor)

    data_to_post = {
      note: "Test note"
    }

    add_auth_header_for(user: tutor)

    post_json "/api/projects/#{student_project.id}/staff_notes", data_to_post
    assert_equal 201, last_response.status

    json = JSON.parse(last_response.body)
    assert_equal data_to_post[:note], json['note']
    assert_equal tutor.id, json['user_id']
  end

  def test_student_cant_get_staff_notes
    unit = FactoryBot.create(:unit, code: 'COS10001')

    student = FactoryBot.create(:user, :student)
    student_project = unit.enrol_student(student, nil)

    tutor = FactoryBot.create(:user, :tutor)
    unit.employ_staff(tutor, Role.tutor)

    StaffNote.create!({
                        note: "Test note!",
                        project: student_project,
                        user: tutor
                      })

    add_auth_header_for(user: student)

    get "/api/projects/#{student_project.id}/staff_notes"
    assert_equal 403, last_response.status
  end

  def test_tutor_not_in_unit_cannot_access_staff_notes
    # Tutor is not employed into any unit, so they shouldn't have access reading staff notes of any project
    tutor = FactoryBot.create(:user, :tutor)

    StaffNote.create!({
                        note: "Test note",
                        project: Project.first,
                        user: tutor
                      })

    add_auth_header_for(user: tutor)

    get "/api/projects/#{Project.first.id}/staff_notes"
    assert_equal 403, last_response.status
  end

  def test_tutor_can_delete_own_staff_notes
    unit = FactoryBot.create(:unit, code: 'COS10001')

    student = FactoryBot.create(:user, :student)
    student_project = unit.enrol_student(student, nil)

    tutor = FactoryBot.create(:user, :tutor)
    unit.employ_staff(tutor, Role.tutor)

    note = StaffNote.create!({
                               note: "Test note for deletion",
                               project: student_project,
                               user: tutor
                             })

    add_auth_header_for(user: tutor)

    delete "/api/projects/#{student_project.id}/staff_notes/#{note.id}"
    assert_equal 200, last_response.status

    assert_nil StaffNote.find_by(id: note.id), 'Staff note was not deleted'
  end

  def test_tutor_cant_delete_other_staff_notes
    unit = FactoryBot.create(:unit, code: 'COS10001')

    student = FactoryBot.create(:user, :student)
    student_project = unit.enrol_student(student, nil)

    tutor1 = FactoryBot.create(:user, :tutor)
    tutor2 = FactoryBot.create(:user, :tutor)
    unit.employ_staff(tutor1, Role.tutor)
    unit.employ_staff(tutor2, Role.tutor)

    note = StaffNote.create!({
                               note: "Test note for deletion",
                               project: student_project,
                               user: tutor1
                             })

    add_auth_header_for(user: tutor2)

    delete "/api/projects/#{student_project.id}/staff_notes/#{note.id}"
    assert_equal 403, last_response.status

    assert StaffNote.find_by(id: note.id), 'Staff note was deleted'
  end

end
