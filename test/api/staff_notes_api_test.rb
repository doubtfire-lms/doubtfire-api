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
    convenor = FactoryBot.create(:user, :convenor)

    unit.employ_staff(tutor, Role.tutor)
    unit.employ_staff(convenor, Role.convenor)

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

    get "/api/csv/units/#{unit.id}/staff_notes"
    assert_equal 200, last_response.status

    add_auth_header_for(user: convenor)

    get "/api/csv/units/#{unit.id}/staff_notes"
    assert_equal 200, last_response.status
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

    # json = JSON.parse(last_response.body)
    # assert_equal data_to_post[:note], json['note']
    # assert_equal tutor.id, json['user_id']
    response_keys = %w[id note user_id reply_to_id]
    response_staff_note = StaffNote.find(last_response_body['id'])
    assert_json_matches_model(response_staff_note, last_response_body, response_keys)

    assert_equal data_to_post[:note], response_staff_note.note
    assert_equal tutor.id, response_staff_note.user_id

    # Reply to the comment we just created
    data_to_post = {
      note: "Second note",
      reply_to_id: response_staff_note.id
    }
    post_json "/api/projects/#{student_project.id}/staff_notes", data_to_post
    assert_equal 201, last_response.status

    second_staff_note = StaffNote.find(last_response_body['id'])
    assert_equal data_to_post[:note], second_staff_note.note
    assert_equal tutor.id, response_staff_note.user_id
    assert_equal response_staff_note.id, second_staff_note.reply_to_id
  end

  def test_only_convenors_and_admins_can_upload_staff_notes_csv
    unit = FactoryBot.create(:unit, code: 'COS10001', with_students: false)
    admin_unit = FactoryBot.create(:unit, code: 'COS10002', with_students: false)
    student = FactoryBot.create(:user, :student, login_id: 'staff-note-student')
    tutor = FactoryBot.create(:user, :tutor)
    convenor = FactoryBot.create(:user, :convenor)
    admin = FactoryBot.create(:user, :admin)
    unit.enrol_student(student, nil)
    admin_unit.enrol_student(student, nil)
    unit.employ_staff(tutor, Role.tutor)
    unit.employ_staff(convenor, Role.convenor)

    csv_file = Tempfile.new(['staff-notes-permissions', '.csv'])
    csv_file.write("username,comment\n#{student.username},Permission test note\n")
    csv_file.rewind

    Sidekiq::Testing.inline! do
      [[convenor, unit], [admin, admin_unit]].each do |user, upload_unit|
        add_auth_header_for(user: user)
        post "/api/csv/units/#{upload_unit.id}/staff_notes", file: Rack::Test::UploadedFile.new(csv_file.path, 'text/csv')
        assert_equal 201, last_response.status, "#{user.role.name}: #{last_response.body}"
      end

      [tutor, student].each do |user|
        add_auth_header_for(user: user)
        post "/api/csv/units/#{unit.id}/staff_notes", file: Rack::Test::UploadedFile.new(csv_file.path, 'text/csv')
        assert_equal 403, last_response.status, user.role.name
      end
    ensure
      Sidekiq::Testing.fake!
    end
  ensure
    csv_file&.close
    csv_file&.unlink
  end

  def test_staff_notes_csv_imports_by_username_or_login_id
    unit = FactoryBot.create(:unit, code: 'COS10001', with_students: false)
    convenor = FactoryBot.create(:user, :convenor)
    first_student = FactoryBot.create(:user, :student, login_id: 'staff-note-login-1')
    second_student = FactoryBot.create(:user, :student, login_id: 'staff-note-login-2')
    first_project = unit.enrol_student(first_student, nil)
    second_project = unit.enrol_student(second_student, nil)
    unit.employ_staff(convenor, Role.convenor)

    csv_file = Tempfile.new(['staff-notes-import', '.csv'])
    csv_file.write(CSV.generate do |csv|
      csv << %w[username login_id comment]
      csv << [first_student.username, nil, 'Username note']
      csv << [nil, second_student.login_id, 'Login ID note']
      csv << [first_student.username, first_student.login_id, 'Duplicate note']
      csv << [first_student.username, first_student.login_id, 'Duplicate note']
      csv << [first_student.username, second_student.login_id, 'Mismatched identifiers note']
    end)
    csv_file.rewind

    Sidekiq::Testing.inline! do
      add_auth_header_for(user: convenor)
      post "/api/csv/units/#{unit.id}/staff_notes", file: Rack::Test::UploadedFile.new(csv_file.path, 'text/csv')

      assert_equal 201, last_response.status, last_response.body
      result = JSON.parse(last_response_body['result'])
      assert_equal 3, result['success'].size
      assert_equal 1, result['ignored'].size
      assert_equal 1, result['errors'].size
      assert_equal 'Staff note already exists', result['ignored'].first['message']
      assert_equal 'Username and login_id do not match the same user', result['errors'].first['message']
      assert_equal ['Username note', 'Duplicate note'], first_project.staff_notes.reload.pluck(:note)
      assert_equal ['Login ID note'], second_project.staff_notes.reload.pluck(:note)
    ensure
      Sidekiq::Testing.fake!
    end
  ensure
    csv_file&.close
    csv_file&.unlink
  end

  def test_tutor_can_edit_staff_notes
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

    data_to_post = {
      note: "Updated note"
    }

    put_json "/api/projects/#{student_project.id}/staff_notes/#{staff_note.id}", data_to_post
    assert_equal 200, last_response.status

    response_keys = %w[id note user_id reply_to_id]
    response_staff_note = StaffNote.find(last_response_body['id'])
    assert_json_matches_model(response_staff_note, last_response_body, response_keys)

    assert_equal staff_note.id, response_staff_note.id
    assert_equal data_to_post[:note], response_staff_note.note
    assert_equal tutor.id, response_staff_note.user_id

    # Ensure tutors can't edit staff notes they didn't create
    tutor2 = FactoryBot.create(:user, :tutor)
    unit.employ_staff(tutor2, Role.tutor)
    add_auth_header_for(user: tutor2)

    put_json "/api/projects/#{student_project.id}/staff_notes/#{staff_note.id}", data_to_post
    assert_equal 403, last_response.status
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

    get "/api/csv/units/#{unit.id}/staff_notes"
    assert_equal 403, last_response.status
  end

  def test_tutor_not_in_unit_cannot_access_staff_notes
    # Tutor is not employed into any unit, so they shouldn't have access reading staff notes of any project
    tutor = FactoryBot.create(:user, :tutor)

    project = Project.first

    StaffNote.create!({
                        note: "Test note",
                        project: project,
                        user: tutor
                      })

    add_auth_header_for(user: tutor)

    get "/api/projects/#{project.id}/staff_notes"
    assert_equal 403, last_response.status

    get "/api/csv/units/#{project.unit.id}/staff_notes"
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

  def test_project_staff_note_count
    unit = FactoryBot.create(:unit, code: 'COS10001')

    student = FactoryBot.create(:user, :student)
    student_project = unit.enrol_student(student, nil)

    tutor1 = FactoryBot.create(:user, :tutor)
    unit.employ_staff(tutor1, Role.tutor)

    # Create 2 staff notes
    StaffNote.create!({
                        note: "Test note 1",
                        project: student_project,
                        user: tutor1
                      })

    StaffNote.create!({
                        note: "Test note 2",
                        project: student_project,
                        user: tutor1
                      })

    add_auth_header_for(user: tutor1)

    get "/api/students?withdrawn=false&unit_id=#{unit.id}"
    assert_equal 200, last_response.status

    matching = JSON.parse(last_response.body).find { |project| project["student"]["id"] == student.id }

    # Ensure project returns a staff note count of 2
    assert_equal 2, matching["staff_note_count"]
  end

end
