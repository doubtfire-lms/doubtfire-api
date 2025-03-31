require "test_helper"

class CourseTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper

  def app
    Rails.application
  end

  def test_default_create
    course = FactoryBot.create(:course)
    assert course.valid?
    course.destroy
  end

  def test_specific_create
    course = FactoryBot.create(:course, name: 'Bachelor of Cyber Security', code: 'S334', year: 2024, version: '1.0', url: 'http://example.com')
    assert_equal 'Bachelor of Cyber Security', course.name
    assert_equal 'S334', course.code
    assert_equal 2024, course.year
    assert_equal '1.0', course.version
    assert_equal 'http://example.com', course.url
    assert course.valid?
    course.destroy
  end

  def test_duplicate_course_is_not_allowed
    course = FactoryBot.create(:course, name: 'Bachelor of Cyber Security', code: 'S334', year: 2024, version: '1.0', url: 'http://example.com')
    duplicate_course = FactoryBot.build(:course, name: 'Bachelor of Cyber Security', code: 'S334', year: 2024, version: '1.0', url: 'http://example.com')
    assert duplicate_course.invalid?
    course.destroy
    duplicate_course.destroy
  end

  def test_name_presence
    course = FactoryBot.build(:course, name: nil)
    assert course.invalid?
    assert_includes course.errors[:name], "can't be blank"
    course.destroy
  end

  def test_code_presence
    course = FactoryBot.build(:course, code: nil)
    assert course.invalid?
    assert_includes course.errors[:code], "can't be blank"
    course.destroy
  end

  def test_year_presence
    course = FactoryBot.build(:course, year: nil)
    assert course.invalid?
    assert_includes course.errors[:year], "can't be blank"
    course.destroy
  end

  def test_version_presence
    course = FactoryBot.build(:course, version: nil)
    assert course.invalid?
    assert_includes course.errors[:version], "can't be blank"
    course.destroy
  end

  def test_url_presence
    course = FactoryBot.build(:course, url: nil)
    assert course.invalid?
    assert_includes course.errors[:url], "can't be blank"
    course.destroy
  end

  def test_code_uniqueness
    course = FactoryBot.create(:course, code: 'S334')
    duplicate_course = FactoryBot.build(:course, code: 'S334')
    assert duplicate_course.invalid?
    assert_includes duplicate_course.errors[:code], "has already been taken"
    course.destroy
    duplicate_course.destroy
  end

  def test_url_format
    course = FactoryBot.build(:course, url: 'invalid_url')
    assert course.invalid?
    assert_includes course.errors[:url], 'is invalid'
    course.destroy
  end

  def test_name_length
    course = FactoryBot.build(:course, name: 'a' * 251)
    assert course.invalid?
    course.destroy
  end

  def test_code_length
    course = FactoryBot.build(:course, code: 'a' * 11)
    assert course.invalid?
    course.destroy
  end

  def test_course_create
    data_to_post = {
      name: "Bachelor of Biochemistry",
      code: "C053",
      year: 2023,
      version: "1.0",
      url: "http://example.com"
    }
    add_auth_header_for user: User.first
    post_json '/api/course', data_to_post
    assert_equal 201, last_response.status
  end

  def test_search_filtering
    course1 = FactoryBot.create(:course, name: 'Bachelor of Data Science', code: 'S379')
    course2 = FactoryBot.create(:course, name: 'Bachelor of Arts', code: 'A300')
    add_auth_header_for user: User.first
    get "/api/course/search?name=Data"
    assert_equal 1, JSON.parse(last_response.body).size
  ensure
    course1.destroy
    course2.destroy
  end

  def test_search_no_parameters
    course1 = FactoryBot.create(:course, name: 'Bachelor of Data Science', code: 'S304', year: 2024, version: '1.0', url: 'http://example.com')
    course2 = FactoryBot.create(:course, name: 'Bachelor of Computer Science', code: 'S364', year: 2024, version: '1.0', url: 'http://example.com')
    course3 = FactoryBot.create(:course, name: 'Bachelor of Arts', code: 'A343', year: 2024, version: '1.0', url: 'http://example.com')
    add_auth_header_for user: User.first
    get "/api/course/search"
    assert_equal 3, JSON.parse(last_response.body).size
  ensure
    course1.destroy
    course2.destroy
    course3.destroy
  end

  def test_update_valid_course
    course = FactoryBot.create(:course)
    updated_data = { name: 'New Name', code: course.code, year: course.year, version: course.version, url: course.url }
    add_auth_header_for user: User.first
    put_json "/api/course/courseId/#{course.id}", updated_data
    assert_equal 200, last_response.status
  ensure
    course.destroy
  end

  def test_update_invalid_course
    course = FactoryBot.create(:course)
    updated_data = { name: '', code: course.code, year: course.year, version: course.version, url: course.url }
    add_auth_header_for user: User.first
    put_json "/api/course/courseId/#{course.id}", updated_data
    assert_equal 400, last_response.status
  ensure
    course.destroy
  end

  def test_delete_existing_course
    course = FactoryBot.create(:course, name: 'Test to delete', code: 'todelete')
    add_auth_header_for user: User.first
    delete_json "/api/course/courseId/#{course.id}"
    assert_equal 0, Courseflow::Course.where(id: course.id).count
    assert_nil Courseflow::Course.find_by(id: course.id)
  ensure
    course.destroy
  end

  def test_delete_non_existent_course
    add_auth_header_for user: User.first
    delete_json "/api/course/courseId/9999"
    assert_equal 404, last_response.status
  end

  def test_course_create_unauthorised
    data_to_post = {
      name: "Bachelor of Biochemistry",
      code: "C053",
      year: 2023,
      version: "1.0",
      url: "http://example.com"
    }
    post_json '/api/course', data_to_post
    assert_equal 419, last_response.status
  end

  def test_wrong_auth_level
    data_to_post = {
      name: "Bachelor of Biochemistry",
      code: "C053",
      year: 2023,
      version: "1.0",
      url: "http://example.com"
    }
    add_auth_header_for user: User.last
    post_json '/api/course', data_to_post
    assert_equal 403, last_response.status
  end

end
