class PortfolioEvidence
  include FileHelper

  def self.sanitized_path(*paths)
    FileHelper.sanitized_path *paths
  end

  def self.sanitized_filename(filename)
    FileHelper.sanitized_filename(filename)
  end

  def self.student_work_dir(type, task = nil)
    FileHelper.student_work_dir(type, task)
  end



  def self.logger
    Rails.logger
  end

  #
  # Combines image, code or documents files given to pdf.
  # Returns the tempfile that was generated. 
  #
  # It is the caller's responsibility to delete this tempfile
  # once the method is finished.
  #
  def self.produce_student_work(files, student, task, ui)
    #
    # Ensure that each file in files has the following attributes:
    # id, name, filename, type, tempfile  
    #
    files.each do | file |
      ui.error!({"error" => "Missing file data for '#{file.name}'"}, 403) if file.id.nil? || file.name.nil? || file.filename.nil? || file.type.nil? || file.tempfile.nil?
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
      if not FileHelper.accept_file(file, file.name, file.type)
        ui.error!({"error" => "'#{file.name}' is not a valid #{file.type} file"}, 403)
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
        "Submission" => "#{file.name}",
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

      coverpage_body = "<h1>#{task.task_definition.name}</h1>\n<dl>"
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



  def self.final_pdf_path_for(task)
    File.join(student_work_dir(:pdf, task), sanitized_filename( sanitized_path("#{task.task_definition.abbreviation}-#{task.id}") + ".pdf"))
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

    # Move files from new to in process
    FileHelper.move_files(new_task_dir, in_process_dir)

    #
    # Create student submission folder (<tmpdir>/doubtfire/pdf/<id>)
    # This is the output directory of all pdfs once compiled from src->pdf
    #
    tmp_dir = File.join( Dir.tmpdir, 'doubtfire', 'pdf', task.id.to_s )

    pdf_paths = FileHelper.convert_files_to_pdf(in_process_dir, tmp_dir)
    if pdf_paths.nil?
      logger.error("Files missing for task #{id}")
      puts "Files missing for task #{id}"
      return
    end
    
    # Get final pdf path -- where the file will be stored
    final_pdf_path = final_pdf_path_for(task)
    
    # Remove old pdf if it exists
    begin
      if File.exists(final_pdf_path)
        File.rm(final_pdf_path)
      end
    rescue
    end

    #
    # Aggregate each of the output PDFs
    #
    if FileHelper.aggregate(pdf_paths, final_pdf_path)
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

    # Move source files from in process to to done folder
    FileHelper.move_files(in_process_dir, student_work_dir(:done, task))
  end  
end