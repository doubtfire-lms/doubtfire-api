# A batch feedback zip received in chunks, so slow connections never outlast a proxy's request timeout.
#
# Each chunk is stored as its own file named "<offset>-<sha256>". A chunk is linked into place, which
# fails if the name exists, so a request retried while the original is still running can't store the
# same chunk twice. No locks are needed, which matters because file locks hang on some NFS mounts.
class BatchFeedbackUpload
  CHUNK_SIZE = 50.megabytes
  EXPIRES_AFTER = 24.hours
  ID_PATTERN = /\A\h{32}\z/
  CHUNK_NAME_PATTERN = /\A(\d{20})-(\h{64})\z/

  class Error < StandardError; end
  class NotFound < Error; end

  class OffsetMismatch < Error
    attr_reader :offset

    def initialize(offset)
      @offset = offset
      super("Expected a chunk starting at byte #{offset}.")
    end
  end

  attr_reader :id, :unit_id, :task_definition_id, :user_id, :filename, :size

  def self.root
    File.join(FileHelper.tmp_file_dir, 'batch-feedback-uploads')
  end

  def self.create(unit:, task_definition:, user:, filename:, size:)
    raise Error, 'Upload size must be greater than zero.' unless size.to_i.positive?

    upload = new(
      id: SecureRandom.hex(16),
      unit_id: unit.id,
      task_definition_id: task_definition.id,
      user_id: user.id,
      filename: File.basename(filename.to_s),
      size: size.to_i
    )

    FileUtils.mkdir_p(upload.chunks_dir)
    File.write(upload.metadata_path, upload.metadata.to_json)
    upload
  end

  def self.find(id)
    return nil unless id.to_s.match?(ID_PATTERN)

    path = File.join(root, id, 'upload.json')
    return nil unless File.exist?(path)

    new(**JSON.parse(File.read(path)).symbolize_keys)
  end

  def self.remove_expired
    Dir.glob(File.join(root, '*')).each do |dir|
      # Storing a chunk updates the chunks directory, not the upload's own directory
      last_activity = [dir, File.join(dir, 'chunks')].select { |path| File.exist?(path) }.map { |path| File.mtime(path) }.max
      FileUtils.rm_rf(dir) if last_activity < EXPIRES_AFTER.ago
    end
  end

  def initialize(id:, unit_id:, task_definition_id:, user_id:, filename:, size:)
    @id = id
    @unit_id = unit_id
    @task_definition_id = task_definition_id
    @user_id = user_id
    @filename = filename
    @size = size
  end

  def dir
    File.join(self.class.root, id)
  end

  def metadata_path
    File.join(dir, 'upload.json')
  end

  def chunks_dir
    File.join(dir, 'chunks')
  end

  def metadata
    { id: id, unit_id: unit_id, task_definition_id: task_definition_id, user_id: user_id, filename: filename, size: size }
  end

  # The chunks received so far, in order from the start of the file.
  def chunks
    received_chunks.map { |chunk| chunk.slice(:size, :sha256) }
  end

  def offset
    received_chunks.sum { |chunk| chunk[:size] }
  end

  def status
    received = chunks
    { id: id, offset: received.sum { |chunk| chunk[:size] }, size: size, chunk_size: CHUNK_SIZE, chunks: received }
  end

  # Stores a chunk that starts at offset, after checking it arrived intact.
  def append(offset, chunk_path, sha256)
    sha256 = sha256.to_s.downcase
    chunk_size = File.size(chunk_path)
    raise Error, 'Chunk is empty.' if chunk_size.zero?
    raise Error, "Chunk exceeds the #{CHUNK_SIZE / 1.megabyte}MB chunk limit." if chunk_size > CHUNK_SIZE
    raise Error, 'Chunk does not match its checksum.' unless Digest::SHA256.file(chunk_path).hexdigest == sha256

    received = self.offset
    raise OffsetMismatch, received unless offset == received
    raise Error, 'Chunk extends past the end of the upload.' if received + chunk_size > size

    # Copy beside the chunks first, as the request's tempfile may be on another filesystem
    temp_path = File.join(chunks_dir, ".tmp-#{SecureRandom.hex(8)}")
    FileUtils.cp(chunk_path, temp_path)
    File.link(temp_path, File.join(chunks_dir, format('%020d-%s', offset, sha256)))
  rescue Errno::EEXIST
    # Another request stored this chunk first
    raise OffsetMismatch, self.offset
  rescue Errno::ENOENT
    raise NotFound
  ensure
    FileUtils.rm_f(temp_path) if temp_path
  end

  # Joins the chunks into the file the import job reads, then yields its path to enqueue the job.
  # The chunks are kept if no job is enqueued, so the caller can complete the upload again later.
  def complete!
    received = received_chunks
    total = received.sum { |chunk| chunk[:size] }
    raise Error, "Upload is incomplete: received #{total} of #{size} bytes." unless total == size

    path = import_path
    temp_path = "#{path}.tmp-#{SecureRandom.hex(8)}"
    File.open(temp_path, 'wb') do |file|
      received.each { |chunk| IO.copy_stream(chunk[:path], file) }
    end
    # Linking fails if another request already completed this upload
    File.link(temp_path, path)

    job_id = yield path
    if job_id.nil?
      FileUtils.rm_f(path)
    else
      FileUtils.rm_rf(dir)
    end
    job_id
  rescue Errno::EEXIST, Errno::ENOENT
    raise NotFound
  ensure
    FileUtils.rm_f(temp_path) if temp_path
  end

  def destroy
    FileUtils.rm_rf(dir)
  end

  private

  # The stored chunks that run on from each other from the start of the file.
  def received_chunks
    received = 0
    stored_chunks.filter_map do |chunk_offset, sha256, path|
      raise Error, 'Upload has conflicting chunks, please start it again.' if chunk_offset < received
      next if chunk_offset > received

      chunk_size = File.size(path)
      received += chunk_size
      { size: chunk_size, sha256: sha256, path: path }
    end
  end

  # [offset, sha256, path] for each stored chunk, sorted by offset.
  def stored_chunks
    Dir.children(chunks_dir).filter_map do |name|
      match = CHUNK_NAME_PATTERN.match(name)
      [match[1].to_i, match[2], File.join(chunks_dir, name)] if match
    end.sort
  rescue Errno::ENOENT
    raise NotFound
  end

  def import_path
    import_dir = File.join(FileHelper.tmp_file_dir, 'batch-feedback')
    FileUtils.mkdir_p(import_dir)

    extension = File.extname(filename)
    extension = '.upload' unless extension.match?(/\A\.[a-z0-9]{1,10}\z/i)
    File.join(import_dir, "batch-feedback-#{unit_id}-#{task_definition_id}-#{id}#{extension}")
  end
end
