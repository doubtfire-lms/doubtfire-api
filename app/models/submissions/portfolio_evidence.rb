require 'tempfile'

# module Submission

  class PortfolioEvidence

    def logger
      Rails.logger
    end

    #
    # Generates a path for storing student work
    # type = [:new, :in_process, :pdfs]
    #
    def student_work_dir(task, type)
      file_server = Doubtfire::Application.config.student_work_dir
      dst = "#{file_server}/#{type}/#{task.id}/"
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
    def produce_student_work(files, student, task)
      
      #
      # Ensure that each file in files has the following attributes:
      # id, name, filename, type, tempfile  
      #
      files.each do | file |
        error!({"error" => "Missing file data for '#{file.name}'"}, 403) if file.id.nil? || file.name.nil? || file.filename.nil? || file.type.nil? || file.tempfile.nil?
      end
     
      # file.key      = "file0"
      # file.name     = front end name for file
      # file.tempfile.path = actual file
      # file.filename = their name for the file

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

      tmp_dir = File.join( Dir.tmpdir, 'doubtfire',  task.id )
      new_dir = student_work_dir(task, "new")

      logger.debug('creating output at #{tmp_dir}, #{new_dir}')

      # ensure the dirs exist
      Dir.mkdir_p(tmp_dir)
      Dir.mkdir_p(new_dir)

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
          # Create cover page
          #
          coverp_file = File.new([tmp_dir, "#{file.key}.cover", ".html"], model="w")
          coverp_file.write(coverpage_body)
          coverp_file.close

          #
          # Now copy the data
          #
          output_filename = File.join(tmp_dir, "#{file.key}", File.extname(file.tempfile.path))
          FileUtils.cp file.tempfile.path, output_filename
      end      
    end
    
    
    
    
    
    
    
    
    # 
    # Alex
    #
    
    
    
    
    
    
    
    
  end
# end