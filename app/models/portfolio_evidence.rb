class PortfolioEvidence

  def self.logger
    Rails.logger
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
  # type = [:new, :in_process, :pdfs]
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
  # Combines image, code or documents files given to pdf.
  # Returns the tempfile that was generated. 
  #
  # It is the caller's responsibility to delete this tempfile
  # once the method is finished.
  #
  def self.produce_student_work(files, student, task)
    #
    # Ensure that each file in files has the following attributes:
    # id, name, filename, type, tempfile  
    #
    files.each do | file |
      error!({"error" => "Missing file data for '#{file.name}'"}, 403) if file.id.nil? || file.name.nil? || file.filename.nil? || file.type.nil? || file.tempfile.nil?
    end
   
    # file.key            = "file0"
    # file.name           = front end name for file
    # file.tempfile.path  = actual file dir
    # file.filename       = their name for the file

    #
    # Confirm subtype categories using filemagic (exception handling
    # must be done outside multithreaded environment below...)
    #
    files.each do | file |
      logger.debug "checking file type for #{file.tempfile.path}"

      fm = FileMagic.new(FileMagic::MAGIC_MIME)
      mime = fm.file file.tempfile.path
      logger.debug "#{file.tempfile.path} is mime type: #{mime}"

      case file.type
      when 'image'
        accept = ["image/png", "image/gif", "image/bmp", "image/tiff", "image/jpeg"]
      when 'code'
        accept = ["text/x-pascal", "text/x-c", "text/x-c++", "text/plain"]
      when 'document'
        accept = [ # -- one day"application/vnd.openxmlformats-officedocument.wordprocessingml.document",
                   # --"application/msword", 
                   "application/pdf" ]
      else
        error!({"error" => "Unknown type '#{file.type}' provided for '#{file.name}'"}, 403)
      end
      
      if not mime.start_with?(*accept)
        error!({"error" => "'#{file.name}' was not an #{file.type} file type"}, 403)
      end
    end
    
    #
    # Create student submission folder (<tmpdir>/doubtfire/new/<id>)
    #
    tmp_dir = File.join( Dir.tmpdir, 'doubtfire', 'new', "#{task.id}" )
    logger.debug("creating tmp dir at #{tmp_dir}")
    
    # ensure the dir exists
    FileUtils.mkdir_p(tmp_dir)

    file_idx = 0
    #
    # Create cover pages for submission
    #
    files.each_with_index.map do | file, idx |        
      #
      # Make file coverpage
      #
      coverpage_data = { 
        "Filename" => "<pre>#{file.filename}</pre>", 
        "Document Type" => file.type.capitalize, 
        "Upload Timestamp" => DateTime.now.strftime("%F %T"), 
        "File Number" => "#{idx+1} of #{files.length}"
      }
      # Add student details if exists
      if not student.nil?
        coverpage_data["Student Name"] = student.name
        coverpage_data["Student ID"] = student.username
      end

      coverpage_body = "<h1>#{file.name}</h1>\n<dl>"
      coverpage_data.each do | key, value |
        coverpage_body << "<dt>#{key}</dt><dd>#{value}</dd>\n"
      end
      coverpage_body << "</dl><footer>Generated with Doubtfire</footer>"
      
      cover_filename = File.join(tmp_dir, "#{file_idx.to_s.rjust(3, '0')}.cover.html")
      file_idx += 1

      logger.debug("generating cover page #{cover_filename}")
      
      #
      # Create cover page for the submitted file (<taskid>/file0.cover.html etc.)
      #
      # puts "generating cover page #{cover_filename}"

      coverp_file = File.new(cover_filename, mode="w")
      # puts 1
      coverp_file.write(coverpage_body)
      # puts 2
      coverp_file.close
      # puts 3

      #
      # Now copy the actual data for the submitted file (<taskid>/file0.image.png etc.)
      #
      output_filename = File.join(tmp_dir, "#{file_idx.to_s.rjust(3, '0')}.#{file.type}#{File.extname(file.filename)}")
      file_idx += 1

      #
      # Set portfolio_evidence to nil while it gets processed
      #
      task.update_attribute(:portfolio_evidence, nil)
      
      # puts file.tempfile.path
      # puts output_filename
      FileUtils.cp file.tempfile.path, output_filename
    end
    
    #
    # Now copy over the temp directory over to the enqueued directory
    #
    enqueued_dir = student_work_dir(:new, task)[0..-2]
    # puts "move ", "#{tmp_dir}", enqueued_dir
    # FileUtils.cp_r "#{tmp_dir}", enqueued_dir

    # move to tmp dir
    Dir.chdir(tmp_dir)
    # move all files to the enq dir
    FileUtils.mv Dir.glob("*"), enqueued_dir
    # FileUtils.rm Dir.glob("*")
    # remove the directory
    Dir.chdir(student_work_dir(:new))
    Dir.rmdir(tmp_dir)
    # puts "done"
  end  

  #
  # Process enqueued pdfs in each folder of the :new directory
  # into PDF files
  #
  def self.process_new_to_pdf
    # For each folder in new (i.e., queued folders to process) that matches appropriate name
    new_root_dir = Dir.entries(student_work_dir(:new)).select { | f | (f =~ /^\d+$/) == 0 }
    new_root_dir.each do | folder_id |
      # begin
        process_task_to_pdf(folder_id)
      # rescue
      #   logger.error "Failed to process folder_id = #{folder_id}"
      # end
    end
  end

  def self.process_task_to_pdf(id)
    #
    # Get access to the task
    #
    task = Task.find(id)

    #
    # Move folder over from new -> in_process
    #
    new_task_dir = student_work_dir(:new, task)
    in_process_root_dir = student_work_dir(:in_process)
    in_process_dir = student_work_dir(:in_process, task)
    if Dir.exists? in_process_dir
      Dir.chdir(in_process_dir)
      # move all files to the enq dir
      FileUtils.rm Dir.glob("*")
    end

    # move into the new dir - and mv 
    Dir.chdir(new_task_dir)
    FileUtils.mv Dir.glob("*"), in_process_dir, :force => true
    Dir.chdir(in_process_root_dir)
    begin
      FileUtils.rm_r(new_task_dir)
    rescue
      logger.warn "failed to rm #{new_task_dir}"
    end

    #
    # Get access to all files to process (ensure we only work with <no>.[cover|document|code|image] etc...)
    #
    in_process_files = Dir.entries(in_process_dir).select { | f | (f =~ /^\d{3}\.(cover|document|code|image)/) == 0 }
    if in_process_files.length < 1
      logger.error "No files found in #{in_process_dir} for Task #{id}"
      puts "Error - No files found in #{in_process_dir} for Task #{id}"
      return
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
      path = "#{in_process_dir}#{file}"
      ext = File.extname(path)
      actualfile = File.open(path)
      files << { :idx => idx, :type => type, :path => path, :ext => ext, :actualfile => actualfile }
    end
    
    #
    # Create student submission folder (<tmpdir>/doubtfire/pdf/<id>)
    # This is the output directory of all pdfs once compiled from src->pdf
    #
    tmp_dir = File.join( Dir.tmpdir, 'doubtfire', 'pdf', task.id.to_s )
    # ensure the dir exists
    FileUtils.mkdir_p(tmp_dir)
    
    #
    # Begin processing... 
    #   @andrew   need to sort it so that cover files will come first... any ideas? ran out of time :(
    #             multithreading isn't working...
    #
    pdf_paths = []
    files.each do | file |
      outpath = "#{tmp_dir}/#{file[:idx]}.#{file[:type]}.pdf"
      
      convert_to_pdf(file, outpath)
      # puts file
      pdf_paths[file[:idx]] = outpath
      begin
        file[:actualfile].close
      rescue
      end
    end
    
    final_pdf_path = File.join(student_work_dir(:pdf, task), sanitized_filename( sanitized_path("#{task.task_definition.abbreviation}-#{task.id}") + ".pdf"))
    
    begin
      if File.exists(final_pdf_path)
        File.rm(final_pdf_path)
      end
    rescue
    end

    #
    # Aggregate each of the output PDFs
    #
    didCompile = system "pdftk #{pdf_paths.join ' '} cat output '#{final_pdf_path}'"
    if !didCompile
      logger.error "failed to create #{final_pdf_path}\n -> pdftk #{pdf_paths.join ' '} cat output #{final_pdf_path}"
      puts "failed to create #{final_pdf_path}\n -> pdftk #{pdf_paths.join ' '} cat output #{final_pdf_path}"
    else
      task.portfolio_evidence = final_pdf_path
      task.save
    end
    
    # Cleanup
    begin
      pdf_paths.each { | path | if File::exist?(path) then FileUtils::rm path end } 
      Dir.rmdir(tmp_dir)
    rescue
      logger.warn "failed to cleanup dirs"
    end
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
  # Read the file and return its contents as a string
  #
  def self.read_file_to_str(filename)
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

  #
  # Converts the cover page provided to a pdf
  #
  def self.cover_to_pdf(file, outdir)
    # puts file
    kit = PDFKit.new(
      read_file_to_str(file[:path]), 
      :page_size => 'A4', 
      :margin_top => "30mm", :margin_right => "30mm", :margin_bottom => "30mm", :margin_left => "30mm"
      )
    kit.stylesheets << Rails.root.join("vendor/assets/stylesheets/doubtfire-coverpage.css")
    kit.to_file outdir
  end
end