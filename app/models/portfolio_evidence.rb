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
    dst = "#{file_server}/#{type}"
    # Add task id to dst if we want task
    if task != nil 
      dst << "/#{task.id}/"
    # Make that directory should it not exist
    FileUtils.mkdir_p(File.dirname(dst))
    dst
  end

  #
  # Combines image, code or documents files given to pdf.
  # Returns the tempfile that was generated. 
  #
  # It is the caller's responsibility to delete this tempfile
  # once the method is finished.
  #
  def produce_student_work(files, student)
    
    #
    # Ensure that each file in files has the following attributes:
    # id, name, filename, type, tempfile  
    #
    files.each do | file |
      error!({"error" => "Missing file data for '#{file.name}'"}, 403) if file.id.nil? || file.name.nil? || file.filename.nil? || file.type.nil? || file.tempfile.nil?
    end
    
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
    # Create student submission folder
    #
    Dir.mkdir(File.join( Dir.tmpdir,   ".foo"))

    #
    # Create cover pages for submission
    #
    files.each_with_index.map do | file, idx |
        #
        # Create dual output documents (coverpage and document itself)
        #
        coverp_file = Tempfile.new(["#{idx}.cover", ".pdf"])
        output_file = Tempfile.new(["#{idx}.data", ".pdf"])
                  
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
        
        logger.debug "pre PDFKit"
        kit = PDFKit.new(coverpage_body, :page_size => 'A4', :margin_top => "30mm", :margin_right => "30mm", :margin_bottom => "30mm", :margin_left => "30mm")
        kit.stylesheets << "vendor/assets/stylesheets/doubtfire-coverpage.css"
        logger.debug "pre kit.to_file #{coverp_file.path}"
        kit.to_file coverp_file.path
        logger.debug "post PDFKit call"

        #
        # File -> PDF
        #  
        case file.type
        #
        # img -> pdf
        #
        when 'image'
          img = Magick::Image.read(file.tempfile.path).first
          # resize the image if its too big (e.g., taken with a digital camera)
          if img.columns > 1000 || img.rows > 500
            # resize such that it's 600px in width
            scale = 1000.0 / img.columns
            img = img.resize(scale)
          end
          img.write("pdf:#{output_file.path}") { self.quality = 75 }
        #
        # code -> html -> pdf
        #
        when 'code'
          # decide language syntax highlighting
          case File.extname(file.filename)
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
          html_body = CodeRay.scan_file(file.tempfile, lang).html(:wrap => :div, :tab_width => 2, :css => :class, :line_numbers => :table, :line_number_anchors => false)

          # HTML -> PDF
          kit = PDFKit.new(html_body, :page_size => 'A4', :header_left => file.filename, :header_right => "[page]/[toPage]", :margin_top => "10mm", :margin_right => "5mm", :margin_bottom => "5mm", :margin_left => "5mm")
          kit.stylesheets << "vendor/assets/stylesheets/coderay.css"
          kit.to_file output_file.path
        #
        # document -> pdf
        #
        when 'document'
          # if uploaded a PDF, then directly pass in
          if File.extname(file.filename) == '.pdf'
            # copy the file over (note we need to copy it into
            # output_file as file will be removed at the end of this block)
            FileUtils.cp file.tempfile.path, output_file.path
          else
          # TODO: convert word -> pdf
            error!({"error" => "Currently, word documents are not supported. Convert the document to PDF first."}, 403)
          end
        end
        
        # Insert (at appropriate index) the converted PDF and its coverpage to pdf_paths array (lock first!)...
        pdf_paths_mutex.synchronize do
          pdf_paths[idx] = [coverp_file.path, output_file.path]
        end
      end
    end.each { | thread | thread.join }
    
    pdf_paths = pdf_paths.flatten
    
    #
    # Aggregate each of the output PDFs
    #
    didCompile = system "pdftk #{pdf_paths.join ' '} cat output #{final_pdf.path}"
    if !didCompile 
      error!({"error" => "PDF failed to compile. Please try again."}, 403)
    end
    
    # We don't need any of those pdf_paths files anymore after compiling the final_pdf!
    pdf_paths.each { | path | if File::exist?(path) then FileUtils::rm path end } 
    files.each { | file | if File::exist?(file.tempfile.path) then file.tempfile.unlink end }
    # We need to do something with this... so we'll let the caller handle that.
    final_pdf
  end
  
  
  
  
  
  
  
  
  # 
  # Alex
  #
  
  #
  # Process enqueued pdfs in each folder of the :new directory
  # into PDF files
  #
  def self.process_pdfs
    # For each folder in new
    #Dir.entries(
  end
  
  
  
  
  
end