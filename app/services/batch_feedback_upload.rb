# A batch feedback zip received in chunks, so slow connections never outlast a proxy's request timeout.
class BatchFeedbackUpload
  CHUNK_SIZE = 50.megabytes
  EXPIRES_AFTER = 24.hours
  ID_PATTERN = /\A\h{32}\z/

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

    FileUtils.mkdir_p(upload.dir)
    File.write(upload.metadata_path, upload.metadata.to_json)
    FileUtils.touch(upload.data_path)
    FileUtils.touch(upload.chunks_path)
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
      data_path = File.join(dir, 'data.part')
      last_activity = File.exist?(data_path) ? File.mtime(data_path) : File.mtime(dir)
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

  def data_path
    File.join(dir, 'data.part')
  end

  # One "size sha256" line per accepted chunk, so a resumed upload can check it is the same file.
  def chunks_path
    File.join(dir, 'chunks.txt')
  end

  def metadata
    { id: id, unit_id: unit_id, task_definition_id: task_definition_id, user_id: user_id, filename: filename, size: size }
  end

  def chunks
    File.readlines(chunks_path, chomp: true).map do |line|
      chunk_size, sha256 = line.split
      { size: chunk_size.to_i, sha256: sha256 }
    end
  rescue Errno::ENOENT
    raise NotFound
  end

  # Bytes received in accepted chunks.
  def offset
    chunks.sum { |chunk| chunk[:size] }
  end

  def status
    { id: id, offset: offset, size: size, chunk_size: CHUNK_SIZE, chunks: chunks }
  end

  # Appends a chunk that starts at offset, after checking it arrived intact.
  def append(offset, chunk_path, sha256)
    chunk_size = File.size(chunk_path)
    raise Error, 'Chunk is empty.' if chunk_size.zero?
    raise Error, "Chunk exceeds the #{CHUNK_SIZE / 1.megabyte}MB chunk limit." if chunk_size > CHUNK_SIZE
    raise Error, 'Chunk does not match its checksum.' unless Digest::SHA256.file(chunk_path).hexdigest == sha256.to_s.downcase

    raise NotFound unless File.exist?(data_path)

    File.open(data_path, 'ab') do |file|
      file.flock(File::LOCK_EX)
      received = offset_under_lock(file)
      raise OffsetMismatch, received unless offset == received
      raise Error, 'Chunk extends past the end of the upload.' if received + chunk_size > size

      IO.copy_stream(chunk_path, file)
      file.flush
      File.open(chunks_path, 'a') { |f| f.puts("#{chunk_size} #{sha256.downcase}") }
    end
  end

  # Moves the finished file to where the import job reads it, then yields that path to enqueue the job.
  # The upload is kept if no job is enqueued, so the caller can complete it again later.
  def complete!
    File.open(data_path, 'rb') do |file|
      file.flock(File::LOCK_EX)
      received = offset_under_lock(file)
      raise Error, "Upload is incomplete: received #{received} of #{size} bytes." unless received == size

      path = import_path
      FileUtils.mv(data_path, path)
      job_id = yield path

      if job_id.nil?
        FileUtils.mv(path, data_path)
      else
        FileUtils.rm_rf(dir)
      end

      job_id
    end
  rescue Errno::ENOENT
    # Another request completed or cancelled this upload first.
    raise NotFound
  end

  def destroy
    FileUtils.rm_rf(dir)
  end

  private

  # Drops any bytes a failed request wrote without recording their chunk.
  def offset_under_lock(file)
    received = offset
    file.truncate(received) if file.size > received
    received
  end

  def import_path
    import_dir = File.join(FileHelper.tmp_file_dir, 'batch-feedback')
    FileUtils.mkdir_p(import_dir)

    extension = File.extname(filename)
    extension = '.upload' unless extension.match?(/\A\.[a-z0-9]{1,10}\z/i)
    File.join(import_dir, "batch-feedback-#{unit_id}-#{task_definition_id}-#{id}#{extension}")
  end
end
