require 'test_helper'

class BatchFeedbackUploadsApiTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper

  def app
    Rails.application
  end

  def setup
    @unit = FactoryBot.create(:unit, with_students: false)
    @task_definition = @unit.task_definitions.first
    @convenor = @unit.main_convenor_user
    ImportBatchFeedbackJob.clear
  end

  def teardown
    @upload_ids&.each { |id| BatchFeedbackUpload.find(id)&.destroy }
  end

  def start_upload(size:, user: @convenor)
    add_auth_header_for(user: user)
    post '/api/submission/batch_feedback_uploads', {
      unit_id: @unit.id,
      task_definition_id: @task_definition.id,
      filename: 'feedback.zip',
      size: size
    }
    return unless last_response.status == 201

    (@upload_ids ||= []) << last_response_body['id']
    last_response_body['id']
  end

  def send_chunk(id, offset, data, sha256: Digest::SHA256.hexdigest(data))
    chunk = Tempfile.new('chunk')
    chunk.binmode
    chunk.write(data)
    chunk.rewind
    patch "/api/submission/batch_feedback_uploads/#{id}", {
      offset: offset,
      sha256: sha256,
      chunk: Rack::Test::UploadedFile.new(chunk.path, 'application/octet-stream')
    }
  ensure
    chunk&.close!
  end

  def test_upload_in_chunks_and_import
    id = start_upload(size: 10)
    assert_equal 0, last_response_body['offset']
    assert_equal BatchFeedbackUpload::CHUNK_SIZE, last_response_body['chunk_size']

    send_chunk(id, 0, 'abcdef')
    assert_equal 200, last_response.status
    assert_equal 6, last_response_body['offset']

    get "/api/submission/batch_feedback_uploads/#{id}"
    assert_equal 6, last_response_body['offset']
    assert_equal [{ 'size' => 6, 'sha256' => Digest::SHA256.hexdigest('abcdef') }], last_response_body['chunks']

    # A retried chunk is rejected and tells the client where to resume
    send_chunk(id, 0, 'abcdef')
    assert_equal 409, last_response.status
    assert_equal 6, last_response_body['offset']

    send_chunk(id, 6, 'ghij')
    assert_equal 10, last_response_body['offset']

    post "/api/submission/batch_feedback_uploads/#{id}/complete"
    assert_equal 201, last_response.status, last_response.body

    assert_equal 1, ImportBatchFeedbackJob.jobs.count
    unit_id, user_id, task_definition_id, path = ImportBatchFeedbackJob.jobs.first['args']
    assert_equal [@unit.id, @convenor.id, @task_definition.id], [unit_id, user_id, task_definition_id]
    assert_equal 'abcdefghij', File.read(path)
    assert_nil BatchFeedbackUpload.find(id)
  ensure
    FileUtils.rm_f(path) if path
  end

  def test_cannot_complete_partial_upload
    id = start_upload(size: 10)
    send_chunk(id, 0, 'abc')

    post "/api/submission/batch_feedback_uploads/#{id}/complete"
    assert_equal 422, last_response.status
    assert_equal 0, ImportBatchFeedbackJob.jobs.count
    assert_equal 3, BatchFeedbackUpload.find(id).offset
  end

  def test_rejects_chunk_that_does_not_match_its_checksum
    id = start_upload(size: 10)

    send_chunk(id, 0, 'abcdef', sha256: Digest::SHA256.hexdigest('abcdeX'))
    assert_equal 422, last_response.status
    assert_equal 0, BatchFeedbackUpload.find(id).offset
  end

  def test_stores_a_chunk_once_when_two_requests_race
    id = start_upload(size: 10)
    send_chunk(id, 0, 'abc')
    upload = BatchFeedbackUpload.find(id)

    # A retry that checked the offset before the original request stored its chunk
    chunk = Tempfile.new('chunk')
    chunk.write('abc')
    chunk.flush
    offset_calls = 0
    upload.define_singleton_method(:offset) { (offset_calls += 1) == 1 ? 0 : super() }
    error = assert_raises(BatchFeedbackUpload::OffsetMismatch) do
      upload.append(0, chunk.path, Digest::SHA256.hexdigest('abc'))
    end

    assert_equal 3, error.offset
    assert_equal [{ size: 3, sha256: Digest::SHA256.hexdigest('abc') }], upload.chunks
    assert_equal 1, Dir.children(upload.chunks_dir).count
  ensure
    chunk&.close!
  end

  def test_rejects_an_upload_with_conflicting_chunks
    id = start_upload(size: 10)
    send_chunk(id, 0, 'abc')
    upload = BatchFeedbackUpload.find(id)
    File.write(File.join(upload.chunks_dir, format('%020d-%s', 0, Digest::SHA256.hexdigest('xyz'))), 'xyz')

    get "/api/submission/batch_feedback_uploads/#{id}"
    assert_equal 422, last_response.status
  end

  def test_rejects_chunk_past_end_of_upload
    id = start_upload(size: 4)

    send_chunk(id, 0, 'abcdef')
    assert_equal 422, last_response.status
    assert_equal 0, BatchFeedbackUpload.find(id).offset
  end

  def test_only_the_uploader_can_use_an_upload
    id = start_upload(size: 10)

    other_convenor = FactoryBot.create(:user, :convenor)
    @unit.employ_staff(other_convenor, Role.convenor)
    add_auth_header_for(user: other_convenor)

    get "/api/submission/batch_feedback_uploads/#{id}"
    assert_equal 404, last_response.status

    send_chunk(id, 0, 'abc')
    assert_equal 404, last_response.status
    assert_equal 0, BatchFeedbackUpload.find(id).offset
  end

  def test_student_cannot_start_upload
    student = FactoryBot.create(:user, :student)
    @unit.enrol_student(student, nil)

    start_upload(size: 10, user: student)
    assert_equal 401, last_response.status
  end

  def test_cancel_upload
    id = start_upload(size: 10)

    delete "/api/submission/batch_feedback_uploads/#{id}"
    assert_equal 204, last_response.status
    assert_nil BatchFeedbackUpload.find(id)
  end

  def test_remove_expired_uploads
    stale_id = start_upload(size: 10)
    fresh_id = start_upload(size: 10)
    stale = BatchFeedbackUpload.find(stale_id)
    FileUtils.touch([stale.dir, stale.chunks_dir], mtime: 2.days.ago.to_time)

    BatchFeedbackUpload.remove_expired

    assert_nil BatchFeedbackUpload.find(stale_id)
    assert_not_nil BatchFeedbackUpload.find(fresh_id)
  end
end
