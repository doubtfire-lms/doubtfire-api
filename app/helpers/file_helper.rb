require 'zip'

module FileHelper
  extend LogHelper
  extend TimeoutHelper
  extend MimeCheckHelpers


  #
  # Test if a file should be accepted based on an expected kind
  # - file is passed the file uploaded to Doubtfire (a hash with all relevant data about the file)
  #
  def accept_file(file, name, kind)
    logger.debug "FileHelper is accepting file: filename=#{file.filename}, name=#{name}, kind=#{kind}"

    valid = true

    case kind
    when 'image'
      accept = ["image/png", "image/gif", "image/bmp", "image/tiff", "image/jpeg", "image/x-ms-bmp"]
    when 'code'
      accept = ["text/x-pascal", "text/x-c", "text/x-c++", "text/plain", "text/", "application/javascript, text/html",
                "text/css", "text/x-ruby", "text/coffeescript", "text/x-scss", "application/json", "text/xml", "application/xml",
                "text/x-yaml", "application/xml", "text/x-typescript"]
    when 'document'
      accept = [ # -- one day"application/vnd.openxmlformats-officedocument.wordprocessingml.document",
                 # --"application/msword",
                 "application/pdf" ]
      valid = pdf_valid? file.tempfile.path
    else
      logger.error "Unknown type '#{kind}' provided for '#{name}'"
      return false
    end

    # result is true when...
    mime_in_list?(file.tempfile.path, accept) && valid
  end


  #
  # Sanitize the passed in paths, and ensure each part is valid
  # Will kill things like ../ etc or spaces in paths
  #
  def sanitized_path(*paths)
    safe_paths = paths.map do | path_name |
      path_name.strip.tap do |name|
        # Finally, replace all non alphanumeric, underscore
        # or periods with underscore
        name.gsub! /[^\w\-]/, '_'
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
    dst << sanitized_path("#{unit.code}-#{unit.id}","TaskFiles") << "/"

    if create and not Dir.exists? dst
      FileUtils.mkdir_p dst
    end

    dst
  end

  def student_group_work_dir(type, group_submission, task=nil, create=false)
    return nil unless group_submission

    file_server = Doubtfire::Application.config.student_work_dir
    dst = "#{file_server}/" # trust the server config and passed in type for paths

    group = group_submission.group
    return nil unless group
    unit = group.unit

    if type == :pdf
      dst << sanitized_path("#{unit.code}-#{unit.id}","Group-#{group.id}", "#{type}") << "/"
    elsif type == :done
      dst << sanitized_path("#{unit.code}-#{unit.id}","Group-#{group.id}", "#{type}", "#{group_submission.id}") << "/"
    elsif type == :plagarism
      dst << sanitized_path("#{unit.code}-#{unit.id}","Group-#{group.id}", "#{type}", "#{group_submission.id}") << "/"
    else  # new and in_process -- just have task id -- will link to group when done etc.
      # Add task id to dst if we want task
      if task.nil?
        raise 'Unable to locate file!'
      end
      dst << "#{type}/#{task.id}/"
    end

    if create
      FileUtils.mkdir_p(dst)
    end
    dst
  end

  #
  # Generates a path for storing student work
  # type = [:new, :in_process, :done, :pdf, :plagarism]
  #
  def student_work_dir(type = nil, task = nil, create = true)
    if task && task.group_task?
      dst = student_group_work_dir type, task.group_submission, task
    else
      file_server = Doubtfire::Application.config.student_work_dir
      dst = "#{file_server}/" # trust the server config and passed in type for paths

      if not (type.nil? || task.nil?)
        if type == :pdf
          dst << sanitized_path("#{task.project.unit.code}-#{task.project.unit.id}","#{task.project.student.username}", "#{type}") << "/"
        elsif type == :done
          dst << sanitized_path("#{task.project.unit.code}-#{task.project.unit.id}","#{task.project.student.username}", "#{type}", "#{task.id}") << "/"
        elsif type == :plagarism
          dst << sanitized_path("#{task.project.unit.code}-#{task.project.unit.id}","#{task.project.student.username}", "#{type}", "#{task.id}") << "/"
        else  # new and in_process -- just have task id
          # Add task id to dst if we want task
          dst << "#{type}/#{task.id}/"
        end
      elsif (not type.nil?)
        if [:in_process, :new].include? type
          # Add task id to dst if we want task
          dst << "#{type}/"
        else
          raise "Error in request to student work directory"
        end
      end
    end

    # Create current dst directory should it not exist
    if create
      FileUtils.mkdir_p(dst)
    end
    dst
  end

  #
  # Generates a path for storing student portfolios
  #
  def student_portfolio_dir(project, create = true)
    file_server = Doubtfire::Application.config.student_work_dir
    dst = "#{file_server}/portfolio/" # trust the server config and passed in type for paths

    dst << sanitized_path("#{project.unit.code}-#{project.unit.id}", "#{project.student.username}" )

    # Create current dst directory should it not exist
    if create
      FileUtils.mkdir_p(dst)
    end
    dst
  end

  def compress_image(path)
    return true if File.size?(path) < 1000000

    compress_folder = File.join(Dir.tmpdir, 'doubtfire', 'compress')

    FileUtils.mkdir compress_folder unless File.directory? compress_folder

    tmp_file = File.join( compress_folder, "#{File.dirname(path).split(File::Separator).last}-file#{File.extname(path)}" )
    logger.debug "File helper has started compressing #{path} to #{tmp_file}..."

    begin
      exec = "convert \
              \"#{path}\" \
              -resize 1024x1024 \
              \"#{tmp_file}\" >>/dev/null 2>>/dev/null"

      did_compress = system_try_within 40, "compressing image using convert", exec

      if did_compress
        FileUtils.mv tmp_file, path
      end
    ensure
      if File.exists? tmp_file
        FileUtils.rm tmp_file
      end
    end

    raise "Failed to compress an image. Ensure all images are smaller than 1MB." unless did_compress
    return true
  end

  def compress_pdf(path, max_size = 2500000)
    # trusting path... as it needs to be replaced
    logger.debug "Compressing PDF #{path} (#{File.size?(path)} bytes) using GhostScript"
    # only compress things over max_size -- defaults to 2.5mb
    return if File.size?(path) < max_size

    begin
      tmp_file = File.join( Dir.tmpdir, 'doubtfire', 'compress', "#{File.dirname(path).split(File::Separator).last}-file.pdf" )
      FileUtils.mkdir_p(File.join( Dir.tmpdir, 'doubtfire', 'compress' ))

      exec = "gs -sDEVICE=pdfwrite \
                 -dCompatibilityLevel=1.3 \
                 -dDetectDuplicateImages=true \
                 -dPDFSETTINGS=/screen \
                 -dNOPAUSE \
                 -dBATCH \
                 -dQUIET \
                 -sOutputFile=\"#{tmp_file}\" \
                 \"#{path}\" \
                 >>/dev/null 2>>/dev/null"

      # try with ghostscript
      did_compress = system_try_within 30, "compressing PDF using ghostscript", exec

      if !did_compress
        logger.info "Failed to compress PDF #{path} using GhostScript. Trying with convert"

        exec = "convert \"#{path}\" \
                -compress Zip \
                \"#{tmp_file}\" \
                >>/dev/null 2>>/dev/null"

        # try with convert
        did_compress = system_try_within 40, "compressing PDF using convert", exec

        if !did_compress
          logger.error "Failed to compress PDF #{path} using convert. Cannot compress this PDF. Command was:\n\t#{exec}"
        end
      end

      if did_compress
        FileUtils.mv tmp_file, path
      end

    rescue => e
      logger.error "Failed to compress PDF #{path}. Rescued with error:\n\t#{e.message}"
    end

    if File.exists? tmp_file
      FileUtils.rm tmp_file
    end
  end

  #
  # Move files between stages - new -> in process -> done
  #
  def move_files(from_path, to_path)
    # move into the new dir - and mv files to the in_process_dir
    pwd = FileUtils.pwd
    begin
      FileUtils.mkdir_p(to_path) if not Dir.exists? to_path
      Dir.chdir(from_path)
      FileUtils.mv Dir.glob("*"), to_path, :force => true
      Dir.chdir(to_path)
      begin
        #remove from_path as files are now "in process"
        FileUtils.rm_r(from_path)
      rescue
        logger.warn "failed to rm #{from_path}"
      end
    ensure
      if FileUtils.pwd() != pwd
        if Dir.exists? pwd
          FileUtils.chdir(pwd)
        else
          FileUtils.chdir( student_work_dir() )
        end
      end
    end
  end

  #
  # Tests if a PDF is valid / corrupt
  #
  def pdf_valid? filename
    # Scan last 1024 bytes for the EOF mark
    return false unless File.exists? filename
    File.open(filename) do |f|
      f.seek -1024, IO::SEEK_END
      f.read.include? '%%EOF'
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
    f = File.open(filename, "r")
    begin
      f.each_line do |line|
        result += line
      end
    ensure
      f.close unless f.nil?
    end
    result
  end

  def path_to_plagarism_html(match_link)
    to_dir = student_work_dir(:plagarism, match_link.task)

    File.join(to_dir, "link_#{match_link.other_task.id}.html")
  end

  #
  # Save the passed in html to a file.
  #
  def save_plagiarism_html(match_link, html)
    File.open(path_to_plagarism_html(match_link), 'w') do |out_file|
      out_file.puts html
    end
  end

  #
  # Delete the html for a plagarism link
  #
  def delete_plagarism_html(match_link)
    rm_file = path_to_plagarism_html(match_link)
    if File.exists? rm_file
      FileUtils.rm(rm_file)
      to_dir = student_work_dir(:plagarism, match_link.task)

      if Dir[File.join(to_dir, '*.html')].count == 0
        FileUtils.rm_rf(to_dir)
      end
    end

    self
  end

  def delete_group_submission(group_submission)
    pdf_file = PortfolioEvidence.final_pdf_path_for_group_submission(group_submission)
    logger.debug "Deleting group submission PDF file #{pdf_file}"
    if File.exists? pdf_file
      FileUtils.rm pdf_file
    end

    done_file = zip_file_path_for_group_done_task(group_submission)
    if File.exists? done_file
      FileUtils.rm done_file
    end
    self
  end

  def zip_file_path_for_group_done_task(group_submission)
    zip_file = "#{student_group_work_dir(:done, group_submission)[0..-2]}.zip"
  end

  def zip_file_path_for_done_task(task)
    zip_file = "#{student_work_dir(:done, task, false)[0..-2]}.zip"
  end

  #
  # Compress the done files for a student - includes cover page and work uploaded
  #
  def compress_done_files(task)
    task_dir = student_work_dir(:done, task, false)
    zip_file = zip_file_path_for_done_task(task)
    return if (zip_file.nil?) || (not Dir.exists? task_dir)

    FileUtils.rm(zip_file) if File.exists? zip_file

    input_files = Dir.entries(task_dir).select { | f | (f =~ /^\d{3}\.(cover|document|code|image)/) == 0 }

    Zip::File.open(zip_file, Zip::File::CREATE) do | zip |
      zip.mkdir "#{task.id}"
      input_files.each do |in_file|
        zip.add "#{task.id}/#{in_file}", "#{task_dir}#{in_file}"
      end
    end

    FileUtils.rm_rf(task_dir)
  end

  def write_entries_to_zip(entries, disk_root_path, zip_root_path, path, zip)
    entries.each do |e|
      # puts "Adding entry #{e}"
      file_path = path == "" ? e : File.join(path, e)
      zip_file_path = zip_root_path == "" ? file_path : File.join(zip_root_path, file_path)
      disk_file_path = File.join(disk_root_path, file_path)

      if File.directory? disk_file_path
        # puts "Making dir: #{zip_file_path} for #{disk_file_path}"
        zip.mkdir(zip_file_path)
        subdir = (Dir.entries(disk_file_path) - %w(. ..))
        # puts "subdir: #{subdir}"
        write_entries_to_zip(subdir, disk_root_path, zip_root_path, file_path, zip)
      else
        # puts "Adding file: #{disk_file_path} -- #{File.exists? disk_file_path}"
        zip.get_output_stream(zip_file_path) do |f|
          f.puts(File.open(disk_file_path, 'rb').read)
        end
      end
    end
  end

  def recursively_add_dir_to_zip(zip, dir, zip_root_path)
    entries = Dir.entries(dir) - %w(. ..)
    zip.mkdir(zip_root_path)
    write_entries_to_zip(entries, dir, zip_root_path, "", zip)
  end

  #
  # Extract the files from the zip file for this tasks, and replace in new so that it is created
  #
  def move_compressed_task_to_new(task)
    # student_work_dir(:new, task) # create task dir
    task.extract_file_from_done student_work_dir(:new), "*", lambda { | task, to_path, name |  "#{to_path}#{name}" }
  end

  # Export functions as module functions
  module_function :accept_file
  module_function :sanitized_path
  module_function :sanitized_filename
  module_function :task_file_dir_for_unit
  module_function :student_group_work_dir
  module_function :student_work_dir
  module_function :student_portfolio_dir
  module_function :compress_image
  module_function :compress_pdf
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
  module_function :compress_done_files
  module_function :move_compressed_task_to_new
  module_function :recursively_add_dir_to_zip
  module_function :write_entries_to_zip
end
