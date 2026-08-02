require 'test_helper'

class UnitContentsApiTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper

  def app
    Rails.application
  end

  def setup
    @unit = FactoryBot.create(:unit, with_students: false, stream_count: 0)
    @archive = Tempfile.new(['unit-content-download', '.zip'])
    write_zip(@archive.path, 'index.html' => '<h1>Unit content</h1>')
    @site = @unit.unit_content_sites.create!(
      name: 'Course site',
      original_filename: 'course site.zip',
      archive_path: @archive.path,
      root_dir: '/'
    )
  end

  def teardown
    @archive.close
    super
  end

  def test_convenor_can_download_content_site_archive
    add_auth_header_for(user: @unit.main_convenor_user)

    get "/api/units/#{@unit.id}/content/sites/#{@site.id}/archive"

    assert_equal 200, last_response.status
    assert_equal 'application/zip', last_response.content_type
    assert_equal 'attachment; filename="course_site.zip"', last_response.headers['Content-Disposition']
    assert_equal File.binread(@archive.path), last_response.body
  end

  def test_student_cannot_download_content_site_archive
    student = FactoryBot.create(:user, :student)
    @unit.enrol_student(student, nil)
    add_auth_header_for(user: student)

    get "/api/units/#{@unit.id}/content/sites/#{@site.id}/archive"

    assert_equal 403, last_response.status
  end

  private

  def write_zip(path, entries)
    Zip::File.open(path, Zip::File::CREATE) do |zip|
      entries.each do |entry_name, contents|
        zip.get_output_stream(entry_name) { |stream| stream.write(contents) }
      end
    end
  end
end
