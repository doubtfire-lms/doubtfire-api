require 'zip'
require 'tmpdir'
require 'open3'
require 'pdf-reader'

module FileHelper
  extend LogHelper
  extend TimeoutHelper
  extend MimeCheckHelpers

  def known_extension?(extn)
    allow_extensions = %w(pdf ps csv xls xlsx pas cpp c cs csv h hpp java py js html coffee scss yaml yml xml json ts r rb rmd rnw rhtml rpres tex vb sql txt md jack hack asm hdl tst out cmp vm sh bat dat ipynb css png bmp tiff tif jpeg jpg gif zip gz tar wav ogg mp3 mp4 webm aac pcm aiff flac wma alac)

    # Allow empty or nil extensions for blobs otherwise check that it matches the allowed list
    extn.nil? || extn.empty? || allow_extensions.include?(extn)
  end

  #
  # Test if a file should be accepted based on an expected kind
  # - file is passed the file uploaded to Doubtfire (a hash with all relevant data about the file)
  #
  def accept_file(file, name, kind)
    valid = true

    case kind
    when 'image'
      accept = ['image/png', 'image/gif', 'image/bmp', 'image/tiff', 'image/jpeg', 'image/x-ms-bmp']
    when 'code'
      accept = ['text/x-pascal', 'text/x-c', 'text/x-c++', 'application/csv', 'text/plain', 'text/', 'application/javascript', 'text/html',
                'text/css', 'text/x-ruby', 'text/coffeescript', 'text/x-scss', 'application/json', 'text/xml', 'application/xml',
                'text/x-yaml', 'application/xml', 'text/x-typescript', 'text/x-vhdl', 'text/x-asm', 'text/x-jack', 'application/x-httpd-php',
                'application/tst', 'text/x-cmp', 'text/x-vm', 'application/x-sh', 'application/x-bat', 'application/dat', 'application/x-wine-extension-ini']
    when 'document'
      accept = [ # -- one day"application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        # --"application/msword",
        'application/pdf'
      ]
      valid = pdf_valid? file["tempfile"].path
    when 'audio'
      accept = ['audio/', 'video/webm', 'application/ogg', 'application/octet-stream']
    when 'comment_attachment'
      accept = ['audio/', 'video/webm', 'application/ogg', 'image/', 'application/pdf', 'application/octet-stream']
    when 'video'
      accept = ['video/mp4']
    else
      logger.error "Unknown type '#{kind}' provided for '#{name}'"
      return false
    end

    mime_in_list?(file["tempfile"].path, accept) && valid && FileHelper.known_extension?(File.extname(file["tempfile"]).downcase[1..])
  end

  #
  # Sanitize the passed in paths, and ensure each part is valid
  # Will kill things like ../ etc or spaces in paths
  #
  def sanitized_path(*paths)
    safe_paths = paths.map do |path_name|
      path_name.strip.tap do |name|
        # Finally, replace all non alphanumeric, underscore
        # or periods with underscore
        name.gsub! /[^\w\-()]/, '_'
      end
    end

    File.join(safe_paths)
  end

  #
  # Sanitize the passed in filename -- should not include any path details
  #
  def sanitized_filename(filename)
    filename.strip.tap do |name|
      # NOTE: File.basename doesn't work right with Windows paths on Unix
      # get only the filename, not the whole path
      name.sub! /\A.*(\\|\/)/, ''
      # Finally, replace all non alphanumeric, underscore
      # or periods with underscore
      name.gsub! /[^\w\.\-]/, '_'
    end
  end

  def task_file_dir_for_unit(unit, create = true)
    file_server = Doubtfire::Application.config.student_work_dir
    dst = "#{file_server}/" # trust the server config and passed in type for paths
    dst << sanitized_path("#{unit.code}-#{unit.id}", 'TaskFiles') << '/'

    FileUtils.mkdir_p dst if create && (!Dir.exist? dst)

    dst
  end

  def tmp_file_dir()
    file_server = Doubtfire::Application.config.student_work_dir
    dst = "#{file_server}/tmp/" # trust the server config and passed in type for paths
    FileUtils.mkdir_p dst

    dst
  end

  def tmp_file(filename)
    tmp_file_dir << sanitized_filename(filename)
  end

  def student_group_work_dir(type, group_submission, task = nil, create = false)
    return nil unless group_submission

    file_server = Doubtfire::Application.config.student_work_dir
    dst = "#{file_server}/" # trust the server config and passed in type for paths

    group = group_submission.group
    return nil unless group

    unit = group.unit

    if type == :pdf
      dst << sanitized_path("#{unit.code}-#{unit.id}", "Group-#{group.id}", type.to_s) << '/'
    elsif [:done, :plagarism].include? type
      dst << sanitized_path("#{unit.code}-#{unit.id}", "Group-#{group.id}", type.to_s, group_submission.id.to_s) << '/'
    else # new and in_process -- just have task id -- will link to group when done etc.
      # Add task id to dst if we want task
      raise 'Unable to locate file!' if task.nil?

      dst << "#{type}/#{task.id}/"
    end

    FileUtils.mkdir_p(dst) if create
    dst
  end

  def student_work_root
    Doubtfire::Application.config.student_work_dir
  end

  #
  # Generates a path for storing student work
  # type = [:new, :in_process, :done, :pdf, :plagarism]
  #
  def student_work_dir(type = nil, task = nil, create = true)
    if task && task.group_task? && type != :comment
      dst = student_group_work_dir type, task.group_submission, task
    else
      file_server = Doubtfire::Application.config.student_work_dir
      dst = "#{file_server}/" # trust the server config and passed in type for paths

      if !(type.nil? || task.nil?)
        if [:discussion, :pdf, :comment].include? type
          dst << sanitized_path("#{task.project.unit.code}-#{task.project.unit.id}", task.project.student.username.to_s, type.to_s) << '/'
        elsif [:done, :plagarism].include? type
          dst << sanitized_path("#{task.project.unit.code}-#{task.project.unit.id}", task.project.student.username.to_s, type.to_s, task.id.to_s) << '/'
        else # new and in_process -- just have task id
          # Add task id to dst if we want task
          dst << "#{type}/#{task.id}/"
        end
      elsif !type.nil?
        if [:in_process, :new].include? type
          # Add task id to dst if we want task
          dst << "#{type}/"
        else
          raise 'Error in request to student work directory'
        end
      end
    end

    # Create current dst directory should it not exist
    FileUtils.mkdir_p(dst) if create
    dst
  end

  def unit_dir(unit, create = true)
    file_server = Doubtfire::Application.config.student_work_dir
    dst = "#{file_server}/" # trust the server config and passed in type for paths
    dst << sanitized_path("#{unit.code}-#{unit.id}") << '/'

    FileUtils.mkdir_p dst if create && (!Dir.exist? dst)

    dst
  end

  def unit_portfolio_dir(unit, create = true)
    file_server = Doubtfire::Application.config.student_work_dir
    dst = "#{file_server}/portfolio/" # trust the server config and passed in type for paths

    dst << sanitized_path("#{unit.code}-#{unit.id}") << '/'

    # Create current dst directory should it not exist
    FileUtils.mkdir_p(dst) if create
    dst
  end

  #
  # Generates a path for storing student portfolios
  #
  def student_portfolio_dir(unit, username, create = true)
    dst = unit_portfolio_dir(unit, create)

    dst << sanitized_path(username.to_s)

    # Create current dst directory should it not exist
    FileUtils.mkdir_p(dst) if create
    dst
  end

  def student_portfolio_path(unit, username, create = true)
    File.join(student_portfolio_dir(unit, username, create), FileHelper.sanitized_filename("#{username}-portfolio.pdf"))
  end

  def comment_attachment_path(task_comment, attachment_extension)
    "#{File.join(student_work_dir(:comment, task_comment.task), "#{task_comment.id.to_s}#{attachment_extension}")}"
  end

  def comment_prompt_path(task_comment, attachment_extension, count)
    "#{File.join(student_work_dir(:discussion, task_comment.task), "#{task_comment.id.to_s}_#{count.to_s}#{attachment_extension}")}"
  end

  def comment_reply_prompt_path(discussion_comment, attachment_extension)
    "#{File.join(student_work_dir(:discussion, discussion_comment.task), "#{discussion_comment.id.to_s}_reply#{attachment_extension}")}"
  end

  def compress_image_to_dest(source, dest, delete_frames = false)
    exec = "convert -quiet \
            \"#{source}\" \
            #{delete_frames ? '-delete 1--1' : ''} -strip -density 72 -quality 85% -resize 2048x2048\\> -resize 48x48\\< \
            \"#{dest}\" >>/dev/null 2>>/dev/null"

    did_compress = system_try_within 40, 'compressing image using convert', exec
  end

  def compress_pdf(path, max_size: 2_500_000, timeout_seconds: 30)
    return unless File.exist? path

    # trusting path... as it needs to be replaced
    # only compress things over max_size -- defaults to 2.5mb

    current_filesize = File.size?(path)
    if current_filesize < max_size
      logger.debug "PDF #{path} (#{current_filesize} bytes) is smaller than #{max_size}, skipping compression."
      return
    end

    begin
      FileUtils.mkdir_p(File.join(Dir.tmpdir, 'doubtfire', 'compress'))

      tmp_file = File.join(Dir.tmpdir, 'doubtfire', 'compress', "#{File.dirname(path).split(File::Separator).last}-file.pdf")

      # Pass 1 - qpdf
      logger.debug "Compressing PDF #{path} (#{current_filesize} bytes) using qpdf"
      exec = "qpdf --recompress-flate --object-streams=generate #{path} #{tmp_file} >>/dev/null 2>>/dev/null"
      did_compress = system_try_within timeout_seconds, 'compressing PDF using qpdf', exec

      if did_compress
        if File.exist?(tmp_file) && File.size?(tmp_file) < current_filesize
          FileUtils.mv tmp_file, path
        else
          FileUtils.rm_f tmp_file
        end
      end

      return did_compress if File.size?(path) < max_size

      # Pass 2 - ghostscript

      logger.debug "Compressing PDF #{path} (#{current_filesize} bytes) using gs"
      exec = "gs -sDEVICE=pdfwrite \
                 -dDetectDuplicateImages=true \
                 -dPDFSETTINGS=/printer \
                 -dNOPAUSE \
                 -dBATCH \
                 -dQUIET \
                 -sOutputFile=\"#{tmp_file}\" \
                 \"#{path}\" \
                 >>/dev/null 2>>/dev/null"

      # try with ghostscript
      did_compress = system_try_within timeout_seconds, 'compressing PDF using ghostscript', exec

      unless did_compress
        logger.error "Failed to compress PDF #{path} using convert. Cannot compress this PDF. Command was:\n\t#{exec}"
      end

      FileUtils.mv tmp_file, path if did_compress && File.size?(tmp_file) < current_filesize
    rescue => e
      logger.error "Failed to compress PDF #{path}. Rescued with error:\n\t#{e.message}"
    end

    FileUtils.rm_f tmp_file
  end

  def pages_in_pdf(path)
    exec = "qpdf --show-npages #{path}"

    out_text, error_text, exit_status = Open3.capture3(exec)
    result = out_text.to_i # will default to 0 if not a number
  rescue => e
    logger.error "Failed to run QPDF on #{path}. Rescued with error:\n\t#{e.message}"
    0
  end

  def qpdf(path)
    exec = "qpdf \"#{path}\" --replace-input >>/dev/null 2>>/dev/null"
    logger.debug "Running QPDF on: #{path}"
    system_try_within 30, "Failed running QPDF on #{path}", exec
  rescue => e
    logger.error "Failed to run QPDF on #{path}. Rescued with error:\n\t#{e.message}"
  end

  #
  # Move files between stages - new -> in process -> done
  # Params:
  # - from path = copy from
  # - to path = destination
  # - retain_from = true if you want to keep from, otherwise it is deleted
  # - only_before = date for files to move (only if retain from is true)
  def move_files(from_path, to_path, retain_from = false, only_before = nil)
    # move into the new dir - and mv files to the in_process_dir
    pwd = FileUtils.pwd
    begin
      FileUtils.mkdir_p(to_path)
      Dir.chdir(from_path)
      FileUtils.mv Dir.glob('*').filter{|fn| !retain_from || only_before.nil? || File.ctime(fn) < only_before}, to_path, force: true
      Dir.chdir(to_path)
      begin
        # remove from_path as files are now "in process"
        # these can be retained when the old folder wants to be kept
        FileUtils.rm_r(from_path) unless retain_from
      rescue
        logger.warn "failed to rm #{from_path}"
      end
    ensure
      if FileUtils.pwd != pwd
        if Dir.exist? pwd
          FileUtils.chdir(pwd)
        else
          FileUtils.chdir(student_work_dir)
        end
      end
    end
  end

  #
  # Tests if a PDF is valid / corrupt
  #
  def pdf_valid?(filename)
    return false unless File.exist? filename
    begin
      reader = PDF::Reader.new(filename)
    rescue PDF::Reader::MalformedPDFError => e
      logger.error "Submitted PDF file #{filename} is invalid: #{e.message}"
      false
    rescue PDF::Reader::EncryptedPDFError => e
      logger.error "Submitted PDF file #{filename} is encrypted: #{e.message}"
      false
    end
  end

  #
  # Copy a PDF into place
  #
  def copy_pdf(file, dest_path)
    if pdf_valid? file
      compress_pdf(file)
      FileUtils.cp file, dest_path
      true
    else
      false
    end
  end

  #
  # Read the file and return its contents as a string
  #
  def read_file_to_str(filename)
    result = ''
    f = File.open(filename, 'r')
    begin
      f.each_line do |line|
        result += line
      end
    ensure
      f.close unless f.nil?
    end
    result
  end

  def path_to_plagarism_html(similarity)
    to_dir = student_work_dir(:plagarism, similarity.task)

    File.join(to_dir, "link_#{similarity.other_task.id}.html")
  end

  #
  # Save the passed in html to a file.
  #
  def save_plagiarism_html(similarity, html)
    File.open(path_to_plagarism_html(similarity), 'w') do |out_file|
      out_file.puts html
    end
  end

  #
  # Delete the html for a plagarism link
  #
  def delete_plagarism_html(similarity)
    rm_file = path_to_plagarism_html(similarity)
    if File.exist? rm_file
      FileUtils.rm(rm_file)
      to_dir = student_work_dir(:plagarism, similarity.task)

      FileUtils.rm_rf(to_dir) if Dir[File.join(to_dir, '*.html')].count.zero?
    end

    self
  end

  def delete_group_submission(group_submission)
    pdf_file = PortfolioEvidence.final_pdf_path_for_group_submission(group_submission)
    logger.debug "Deleting group submission PDF file #{pdf_file}"
    FileUtils.rm_f pdf_file

    done_file = zip_file_path_for_group_done_task(group_submission)
    FileUtils.rm_f done_file
    self
  end

  def zip_file_path_for_group_done_task(group_submission)
    zip_file = "#{student_group_work_dir(:done, group_submission)[0..-2]}.zip"
  end

  def zip_file_path_for_done_task(task)
    zip_file = "#{student_work_dir(:done, task, false)[0..-2]}.zip"
  end

  def zip_file_path_for_discussion_prompts(task)
    zip_file = "#{student_work_dir(:discussion, task, false)[0..-2]}.zip"
  end

  #
  # Compress the done files for a student - includes cover page and work uploaded
  #
  def compress_done_files(task)
    task_dir = student_work_dir(:done, task, false)
    zip_file = zip_file_path_for_done_task(task)
    return if zip_file.nil? || (!Dir.exist? task_dir)

    FileUtils.rm_f(zip_file)

    input_files = Dir.entries(task_dir).select { |f| (f =~ /^\d{3}\.(cover|document|code|image)/).zero? }

    Zip::File.open(zip_file, Zip::File::CREATE) do |zip|
      zip.mkdir task.id.to_s
      input_files.each do |in_file|
        zip.add "#{task.id}/#{in_file}", "#{task_dir}#{in_file}"
      end
    end

    FileUtils.rm_rf(task_dir)
  end

  def write_entries_to_zip(entries, disk_root_path, zip_root_path, path, zip)
    entries.each do |e|
      # puts "Adding entry #{e}"
      file_path = path == '' ? e : File.join(path, e)
      zip_file_path = zip_root_path == '' ? file_path : File.join(zip_root_path, file_path)
      disk_file_path = File.join(disk_root_path, file_path)

      if File.directory? disk_file_path
        # puts "Making dir: #{zip_file_path} for #{disk_file_path}"
        zip.mkdir(zip_file_path)
        subdir = (Dir.entries(disk_file_path) - %w(. ..))
        # puts "subdir: #{subdir}"
        write_entries_to_zip(subdir, disk_root_path, zip_root_path, file_path, zip)
      else
        # puts "Adding file: #{disk_file_path} -- #{File.exist? disk_file_path}"
        zip.get_output_stream(zip_file_path) do |f|
          f.puts(File.binread(disk_file_path))
        end
      end
    end
  end

  def recursively_add_dir_to_zip(zip, dir, zip_root_path)
    entries = Dir.entries(dir) - %w(. ..)
    zip.mkdir(zip_root_path)
    write_entries_to_zip(entries, dir, zip_root_path, '', zip)
  end

  #
  # Extract the files from the zip file for this tasks, and replace in new so that it is created
  #
  def move_compressed_task_to_new(task)
    # student_work_dir(:new, task) # create task dir
    task.extract_file_from_done student_work_dir(:new), '*', ->(_task, to_path, name) { "#{to_path}#{name}" }
  end

  #
  # Ensure that the contents of a file appear to be valid UTF8, on retry convert to ASCII to ensure
  #
  def ensure_utf8_code(output_filename, force_ascii)
    # puts "Converting #{output_filename} to utf8"
    tmp_filename = Dir::Tmpname.create(["new", ".code"]) { |name| raise Errno::EEXIST if File.exist?(name)  }

    # Convert to utf8 from read encoding
    if force_ascii
      `iconv -c -t ascii "#{output_filename}" > "#{tmp_filename}"`
    else
      `iconv -c -t UTF-8 "#{output_filename}" > "#{tmp_filename}"`
    end

    # Move into place
    FileUtils.mv(tmp_filename, output_filename)
  end

  def process_audio(input_path, output_path)
    logger.info("Trying to process audio in FileHelper")
    path = Doubtfire::Application.config.institution[:ffmpeg]
    TimeoutHelper.system_try_within 20, "Failed to process audio submission - timeout", "#{path} -loglevel quiet -y -i #{input_path} -ac 1 -ar 16000 -sample_fmt s16 #{output_path}"
  end

  def sorted_timestamp_entries_in_dir(path)
    Dir.entries(path).grep(/\d+/).sort_by { |x| File.basename(x) }.reverse
  end

  def latest_submission_timestamp_entry_in_dir(path)
    sorted_timestamp_entries_in_dir(path)[0]
  end

  def task_submission_identifier_path(type, task)
    file_server = Doubtfire::Application.config.student_work_dir
    "#{file_server}/submission_history/#{sanitized_path("#{task.project.unit.code}-#{task.project.unit.id}", task.project.student.username.to_s, type.to_s, task.id.to_s)}"
  end

  def task_submission_identifier_path_with_timestamp(type, task, timestamp)
    "#{task_submission_identifier_path(type, task)}/#{timestamp.to_s}"
  end

  # Export functions as module functions
  module_function :accept_file
  module_function :sanitized_path
  module_function :sanitized_filename
  module_function :task_file_dir_for_unit
  module_function :tmp_file_dir
  module_function :tmp_file
  module_function :student_group_work_dir
  module_function :student_work_dir
  module_function :student_work_root
  module_function :unit_dir
  module_function :unit_portfolio_dir
  module_function :student_portfolio_dir
  module_function :student_portfolio_path
  module_function :comment_attachment_path
  module_function :comment_prompt_path
  module_function :comment_reply_prompt_path
  module_function :compress_image_to_dest
  module_function :compress_pdf
  module_function :qpdf
  module_function :move_files
  module_function :pdf_valid?
  module_function :copy_pdf
  module_function :read_file_to_str
  module_function :path_to_plagarism_html
  module_function :save_plagiarism_html
  module_function :delete_plagarism_html
  module_function :delete_group_submission
  module_function :zip_file_path_for_group_done_task
  module_function :zip_file_path_for_done_task
  module_function :zip_file_path_for_discussion_prompts
  module_function :compress_done_files
  module_function :move_compressed_task_to_new
  module_function :recursively_add_dir_to_zip
  module_function :write_entries_to_zip
  module_function :ensure_utf8_code
  module_function :process_audio
  module_function :sorted_timestamp_entries_in_dir
  module_function :latest_submission_timestamp_entry_in_dir
  module_function :task_submission_identifier_path
  module_function :task_submission_identifier_path_with_timestamp
  module_function :known_extension?
  module_function :pages_in_pdf
end
