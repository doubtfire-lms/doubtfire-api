class PortfolioEvidence

  def logger
    Rails.logger
  end

  #
  # Generates a path for storing student work
  # type = [:new, :in_process, :pdfs]
  #
  def self.student_work_dir(type, task = nil)
    file_server = Doubtfire::Application.config.student_work_dir
    dst = "#{file_server}/#{type}/"
    # Create current dst directory should it not exist
    FileUtils.mkdir_p(dst)
    # Add task id to dst if we want task
    if task != nil 
      dst << "#{task.id}/"
      # Create the task id directory should it not exist
      FileUtils.mkdir_p(dst)
    end
    dst
  end

  #
  # Combines image, code or documents files given to pdf.
  # Returns the tempfile that was generated. 
  #
  # It is the caller's responsibility to delete this tempfile
  # once the method is finished.
  #
  def produce_student_work(files, student, task)
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
    tmp_dir = File.join( Dir.tmpdir, 'doubtfire', 'new', task.id )
    logger.debug('creating output at #{tmp_dir}, #{new_dir}')
    # ensure the dir exists
    Dir.mkdir_p(tmp_dir)

    #
    # Create cover pages for submission
    #
    files.each_with_index.map do | file, idx |        
      #
      # Make file coverpage
      #
      coverpage_data = { "Filename" => "<pre>#{file.filename}</pre>", "Document Type" => file.type.capitalize, "Upload Timestamp" => DateTime.now.strftime("%F %T"), "File Number" => "#{idx+1} of #{files.length}"}
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
      
      logger.debug "generating cover page #{file.key}.cover.html"
      
      #
      # Create cover page for the submitted file (<taskid>/file0.cover.html etc.)
      #
      coverp_file = File.new([tmp_dir, "#{file.key}.cover", ".html"], model="w")
      coverp_file.write(coverpage_body)
      coverp_file.close

      #
      # Now copy the actual data for the submitted file (<taskid>/file0.image.png etc.)
      #
      output_filename = File.join(tmp_dir, "#{file.key}.#{file.type}", File.extname(file.tempfile.path))
      FileUtils.cp file.tempfile.path, output_filename
    end
    
    #
    # Now copy over the temp directory over to the enqueued directory
    #
    enqueued_dir = student_work_dir(:new, task.id)
    FileUtils.cp tmp_dir, enqueued_dir
    
    # Cleanup
    FileUtils.rmdir tmp_dir
  end  

  #
  # Process enqueued pdfs in each folder of the :new directory
  # into PDF files
  #
  def self.process_new_to_pdf
    # For each folder in new (i.e., queued folders to process)
    new_root_dir = Dir.entries(student_work_dir(:new)).reject { | f | f == "." || f == ".." }
    new_root_dir.each do | folder_id |
      process_task_to_pdf(folder_id)
    end
  end

  def self.process_task_to_pdf(id)
    #
    # Get access to the task
    #
    task = Task.find(id)
    
    #
    # Move folder over from new -> in_provess
    #
    new_task_dir = student_work_dir(:new, task)
    in_process_root_dir = student_work_dir(:in_process)
    FileUtils.mv new_task_dir, in_process_root_dir
    
    #
    # Get access to all files to process
    #
    in_process_dir = student_work_dir(:in_process, task)
    in_process_files = Dir.entries(in_process_dir).reject { | f | f == "." || f == ".." }

    #
    # Map each process file to have extra info i.e.:
    #
    # file.key            = "file0"
    # file.path           = actual file dir sitting in in_process directory
    # file.ext            = file extension
    # file.type           = image/code/document
    # file.actualfile     = actual file variable that can be used - File.open(path)
    #
    files = []
    in_process_files.each do | file |
      # file0.code.png
      key = file.split('.').first
      type = file.split('.').second
      path = "#{in_process_dir}#{file}"
      ext = File.extname(path)
      actualfile = File.open(path)
      files << { :key => key, :type => type, :path => path, :ext => ext, :actualfile => actualfile }
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
    #   @andrew, need to sort it so that cover files will come first... any ideas? ran out of time :(
    # 
    pdf_paths = []
    pdf_paths_mutex = Mutex.new
    files.each_with_index do | file, idx |
      Thread.new do
        outdir = "#{tmp_dir}/#{file.key}.#{file.type}.pdf"
        
        convert_to_pdf(file, outdir)
        
        pdf_paths_mutex.synchronize do
          pdf_paths[idx] = outdir
        end
      end
    end.each { | thread | thread.join }
    
    pdf_paths = pdf_paths.flatten
    
    final_pdf_path = "#{student_work_dir(:pdf, task)}#{task.abbrev}-#{task.id}.pdf"
    
    #
    # Aggregate each of the output PDFs
    #
    didCompile = system "pdftk #{pdf_paths.join ' '} cat output #{final_pdf_path}"
    if !didCompile 
      #
      # @andrew What should happen on an error?
      #
    end
    
    # Cleanup
    pdf_paths.each { | path | if File::exist?(path) then FileUtils::rm path end } 
  end

  #
  # Converts the given file to a pdf
  #  
  def self.convert_to_pdf(file, outdir)
    case file.type
    when 'image'
      img_to_pdf(file, outdir)
    when 'code'
      code_to_pdf(file, outdir)
    when 'document', 'cover'
      doc_to_pdf(file, outdir)
    end
  end
  
  #
  # Converts the code provided to a pdf
  #
  def self.code_to_pdf(file, outdir)
    # decide language syntax highlighting
    case file.ext
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
    html_body = CodeRay.scan_file(file.actualfile, lang).html(:wrap => :div, :tab_width => 2, :css => :class, :line_numbers => :table, :line_number_anchors => false)

    # HTML -> PDF
    kit = PDFKit.new(html_body, :page_size => 'A4', :header_right => "[page]/[toPage]", :margin_top => "10mm", :margin_right => "5mm", :margin_bottom => "5mm", :margin_left => "5mm")
    kit.stylesheets << "vendor/assets/stylesheets/coderay.css"
    kit.to_file(outdir)
  end
  
  #
  # Converts the image provided to a pdf
  #
  def self.img_to_pdf(file, outdir)
    img = Magick::Image.read(file.path).first
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
    if file.ext == '.pdf'
      # copy the file over (note we need to copy it into
      # output_file as file will be removed at the end of this block)
      FileUtils.cp file.path, outdir
    end
    # TODO msword doc...
  end
end