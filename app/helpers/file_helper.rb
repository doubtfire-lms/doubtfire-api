module FileHelper

  # Provide access to the Rails logger
  def self.logger
    Rails.logger
  end

  #
  # Test if a file should be accepted based on an expected kind
  # - file is passed the file uploaded to Doubtfire
  #
  def self.accept_file(file, name, kind)
    logger.debug "FileHelper accept_file #{file}, #{name}, #{kind}"

    fm = FileMagic.new(FileMagic::MAGIC_MIME)
    mime = fm.file file.tempfile.path
    logger.debug " -- #{name} is mime type: #{mime}"

    case kind
    when 'image'
      accept = ["image/png", "image/gif", "image/bmp", "image/tiff", "image/jpeg"]
    when 'code'
      accept = ["text/x-pascal", "text/x-c", "text/x-c++", "text/plain"]
    when 'document'
      accept = [ # -- one day"application/vnd.openxmlformats-officedocument.wordprocessingml.document",
                 # --"application/msword", 
                 "application/pdf" ]
    else
      logger.error "Unknown type '#{kind}' provided for '#{name}'"
      return false
    end
    
    # result is true when...
    mime.start_with?(*accept)
  end


  #
  # Sanitize the passed in paths, and ensure each part is valid
  # Will kill things like ../ etc or spaces in paths
  #
  def self.sanitized_path(*paths)
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
  def self.sanitized_filename(filename)
    filename.strip.tap do |name|
      # NOTE: File.basename doesn't work right with Windows paths on Unix
      # get only the filename, not the whole path
      name.sub! /\A.*(\\|\/)/, ''
      # Finally, replace all non alphanumeric, underscore
      # or periods with underscore
      name.gsub! /[^\w\.\-]/, '_'
    end
  end

  #
  # Generates a path for storing student work
  # type = [:new, :in_process, :pdf]
  #
  def self.student_work_dir(type, task = nil)
    file_server = Doubtfire::Application.config.student_work_dir
    dst = "#{file_server}/#{type}/" # trust the server config and passed in type for paths

    if task != nil 
      if type == :pdf || type == :in_process
        dst << sanitized_path("#{task.project.unit.code}-#{task.project.unit.id}","#{task.project.student.username}") << "/"
      elsif 
        # Add task id to dst if we want task
        dst << "#{task.id}/"
      end
    end

    # Create current dst directory should it not exist
    FileUtils.mkdir_p(dst)
    dst
  end

  #
  # Generates a path for storing student portfolios
  #
  def self.student_portfolio_dir(project, create = true)
    file_server = Doubtfire::Application.config.student_work_dir
    dst = "#{file_server}/portfolio/" # trust the server config and passed in type for paths

    dst << sanitized_path("#{project.unit.code}-#{project.unit.id}", "#{project.student.username}" )

    # Create current dst directory should it not exist
    if create
      FileUtils.mkdir_p(dst)
    end
    dst
  end


  #
  # Converts the given file to a pdf
  #  
  def self.convert_to_pdf(file, outdir)
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
  def self.code_to_pdf(file, outdir)
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
    kit = PDFKit.new(html_body, :page_size => 'A4', :header_right => "[page]/[toPage]", :margin_top => "10mm", :margin_right => "5mm", :margin_bottom => "5mm", :margin_left => "5mm")
    kit.stylesheets << Rails.root.join("vendor/assets/stylesheets/coderay.css")
    kit.to_file(outdir)
  end
  
  #
  # Converts the image provided to a pdf
  #
  def self.img_to_pdf(file, outdir)
    img = Magick::Image.read(file[:path]).first
    # resize the image if its too big (e.g., taken with a digital camera)
    if img.columns > 1000 || img.rows > 500
      # resize such that it's 600px in width
      scale = 1000.0 / img.columns
      img = img.resize(scale)
    end
    img.write("pdf:#{outdir}") { self.quality = 75 }
  end

  #
  # Converts the document provided to a pdf
  #
  def self.doc_to_pdf(file, outdir)
    # if uploaded a PDF, then directly pass in
    if file[:ext] == '.pdf'
      # copy the file over (note we need to copy it into
      # output_file as file will be removed at the end of this block)
      FileUtils.cp file[:path], outdir
    end
    # TODO msword doc...
  end

  #
  # Aggregate a list of PDFs into a single PDF file
  # - returns boolean indicating success
  #
  def self.aggregate(pdf_paths, final_pdf_path)
    didCompile = system "pdftk #{pdf_paths.join ' '} cat output '#{final_pdf_path}'"
    if !didCompile
      logger.error "failed to create #{final_pdf_path}\n -> pdftk #{pdf_paths.join ' '} cat output #{final_pdf_path}"
      puts "failed to create #{final_pdf_path}\n -> pdftk #{pdf_paths.join ' '} cat output #{final_pdf_path}"
    end
    didCompile
  end
end
