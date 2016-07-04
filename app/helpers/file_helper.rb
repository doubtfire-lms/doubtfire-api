require 'zip'

module FileHelper
  extend LogHelper
  extend TimeoutHelper

  def check_mime_against_list! (file, expect, type_list)
    fm = FileMagic.new(FileMagic::MAGIC_MIME)

    mime_type = fm.file(file)

    # check mime is correct before uploading
    if not mime_type.start_with?(*type_list)
      error!({"error" => "File given is not a #{expect} file - detected #{mime_type}"}, 403)
    end
  end

  #
  # Test if a file should be accepted based on an expected kind
  # - file is passed the file uploaded to Doubtfire (a hash with all relevant data about the file)
  #
  def accept_file(file, name, kind)
    logger.debug "FileHelper is accepting file: filename=#{file.filename}, name=#{name}, kind=#{kind}"

    fm = FileMagic.new(FileMagic::MAGIC_MIME)
    mime = fm.file file.tempfile.path
    logger.debug "#{name} has MIME type: #{mime}"

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
    mime.start_with?(*accept) && valid
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

    tmp_file = File.join( Dir.tmpdir, 'doubtfire', 'compress', "#{File.dirname(path).split(File::Separator).last}-file#{File.extname(path)}" )
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
  # Convert the files in the indicated folder into PDFs and move to
  # a dest_path
  #
  def convert_files_to_pdf(from_path, dest_path)
    #
    # Get access to all files to process (ensure we only work with <no>.[cover|document|code|image] etc...)
    #
    in_process_files = Dir.entries(from_path).select { | f | (f =~ /^\d{3}\.(cover|document|code|image)/) == 0 }
    if in_process_files.length < 1
      logger.error "Cannot convert files to PDF: No files found in #{from_path}"
      return nil
    end

    #
    # Map each process file to have extra info i.e.:
    #
    # file.idx            = 0..n
    # file.path           = actual file dir sitting in in_process directory
    # file.ext            = file extension
    # file.type           = cover/image/code/document
    # file.actualfile     = actual file variable that can be used - File.open(path)
    #
    files = []
    in_process_files.each do | file |
      # file0.code.png
      idx = file.split('.').first.to_i
      type = file.split('.').second
      path = File.join("#{from_path}", "#{file}")
      ext = File.extname(path).downcase
      actualfile = File.open(path)
      files << { :idx => idx, :type => type, :path => path, :ext => ext, :actualfile => actualfile }
    end

    # ensure the dest_path exists
    if not Dir.exists? dest_path
      FileUtils.mkdir_p(dest_path)
    end

    #
    # Begin processing...
    #
    pdf_paths = []
    files.each do | file |
      outpath = "#{dest_path}/#{file[:idx]}-#{file[:type]}.pdf"

      convert_to_pdf(file, outpath)

      pdf_paths[file[:idx]] = outpath
      begin
        file[:actualfile].close
      rescue
      end
    end

    pdf_paths
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
  # Converts the given file to a pdf
  #
  def convert_to_pdf(file, outdir)
    case file[:type]
    when 'image'
      img_to_pdf(file, outdir)
    when 'code'
      code_to_pdf(file, outdir)
    when 'document'
      doc_to_pdf(file, outdir)
    when 'cover'
      cover_to_pdf(file, outdir)
    end
  end

  #
  # Converts the code provided to a pdf
  #
  def code_to_pdf(file, outdir)
    # decide language syntax highlighting
    case file[:ext]
    when '.cpp', '.cs'
      lang = :cplusplus
    when '.c', '.h'
      lang = :c
    when '.java'
      lang = :java
    when '.pas'
      lang = :delphi
    else
      # should follow basic C syntax (if, else etc...)
      lang = :c
    end
    # code -> HTML
    html_body = CodeRay.scan_file(file[:actualfile], lang).html(:wrap => :div, :tab_width => 2, :css => :class, :line_numbers => :table, :line_number_anchors => false)

    # HTML -> PDF
    kit = PDFKit.new(html_body, :page_size => 'A4', :header_right => "[page]/[toPage]", :margin_top => "10mm", :margin_right => "5mm", :margin_bottom => "5mm", :margin_left => "5mm", :lowquality => true, :minimum_font_size => 8)
    kit.stylesheets << Rails.root.join("vendor/assets/stylesheets/coderay.css")
    kit.to_file(outdir)
  end

  #
  # Converts the image provided to a pdf
  #
  def img_to_pdf(file, outdir)
    img = Magick::Image.read(file[:path]).first
    # resize the image if its too big (e.g., taken with a digital camera)
    if img.columns > 1000 || img.rows > 1000
      # resize such that it's 1000px in width
      scale = 1
      if img.columns > img.rows
        scale = 1000.0 / img.columns
      else
        scale = 1000.0 / img.rows
      end
      img = img.resize(scale)
    end
    img.write("pdf:#{outdir}") { self.quality = 75 }
  end

  #
  # Converts the document provided to a pdf
  #
  def doc_to_pdf(file, outdir)
    logger.info "Trying to convert document file #{file[:path]} to PDF"
    # if uploaded a PDF, then directly pass in
    # if file[:ext] == '.pdf'
      # copy the file over (note we need to copy it into
      # output_file as file will be removed at the end of this block)

      begin
        file[:actualfile].close()
      rescue => e
        logger.error "File could not be converted: #{e.message}"
      end

      copy_pdf(file[:path], outdir)

      begin
        file[:actualfile] = File.open(file[:path])
      rescue => e
        logger.error "File could not be converted: #{e.message}"
      end
    # end

    # TODO msword doc...
  end

  #
  # Converts the cover page provided to a pdf
  #
  def cover_to_pdf(file, outdir)
    kit = PDFKit.new(
      read_file_to_str(file[:path]),
      :page_size => 'A4',
      :margin_top => "30mm", :margin_right => "30mm", :margin_bottom => "30mm", :margin_left => "30mm"
      )
    kit.stylesheets << Rails.root.join("vendor/assets/stylesheets/doubtfire-coverpage.css")
    kit.to_file outdir
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

  #
  # Extract the files from the zip file for this tasks, and replace in new so that it is created
  #
  def move_compressed_task_to_new(task)
    # student_work_dir(:new, task) # create task dir
    extract_file_from_done task, student_work_dir(:new), "*", lambda { | task, to_path, name |  "#{to_path}#{name}" }
  end

  #
  # Extract files matching a pattern from the
  #
  def extract_file_from_done(task, to_path, pattern, name_fn)
    zip_file = zip_file_path_for_done_task(task)
    return false if (zip_file.nil?) ||  (not File.exists? zip_file)

    Zip::File.open(zip_file) do |zip|
      # Extract folders
      zip.each do |entry|
        # Extract to file/directory/symlink
        logger.debug "Extract files from done is extracting #{entry.name}"
        if entry.name_is_directory?
          entry.extract( name_fn.call(task, to_path, entry.name) )  { true }
        end
      end
      zip.glob("**/#{pattern}").each do |entry|
        entry.extract( name_fn.call(task, to_path, entry.name) ) { true }
      end
    end
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
  module_function :convert_files_to_pdf
  module_function :pdf_valid?
  module_function :copy_pdf
  module_function :convert_to_pdf
  module_function :code_to_pdf
  module_function :img_to_pdf
  module_function :doc_to_pdf
  module_function :cover_to_pdf
  module_function :read_file_to_str
  module_function :path_to_plagarism_html
  module_function :save_plagiarism_html
  module_function :delete_plagarism_html
  module_function :delete_group_submission
  module_function :zip_file_path_for_group_done_task
  module_function :zip_file_path_for_done_task
  module_function :compress_done_files
  module_function :move_compressed_task_to_new
  module_function :extract_file_from_done
end
