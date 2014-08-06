# getting file MIME types
require 'filemagic'
# image to pdf
require 'RMagick'
# code to html
require 'coderay'
# html to pdf
require 'pdfkit'
# zipping files
require 'zip'

module Api::Submission::GenerateHelpers
  
  def logger
    # Grape::API.logger
    Rails.logger
  end

  #
  # Scoops out a files array from the params provided
  #
  def scoop_files(params, upload_reqs)
    files = params.reject { | key | not key =~ /^file\d+$/ }

    error!({"error" => "Upload requirements mismatch with files provided"}, 403) if files.length != upload_reqs.length 
    #
    # Pair the name and type from upload_requirements to each file
    #
    upload_reqs.each do | detail |
      key = detail['key']
      if files.has_key? key
        files[key].id   = files[key].name
        files[key].name = detail['name']
        files[key].type = detail['type']
      end
    end
    
    # File didn't get assigned an id above, then reject it since there was a mismatch
    files = files.reject { | key, file | file.id.nil? }
    error!({"error" => "Upload requirements mismatch with files provided"}, 403) if files.length != upload_reqs.length 

    # Kill the kvp
    files.map{ | k, v | v }
  end
  
  # #
  # # Combines image, code or documents files given to pdf.
  # # Returns the tempfile that was generated. 
  # #
  # # It is the caller's responsibility to delete this tempfile
  # # once the method is finished.
  # #
  # def combine_to_pdf(files, student = nil)
  #   #
  #   # Ensure that each file in files has the following attributes:
  #   # id, name, filename, type, tempfile  
  #   #
  #   files.each do | file |
  #     error!({"error" => "Missing file data for '#{file.name}'"}, 403) if file.id.nil? || file.name.nil? || file.filename.nil? || file.type.nil? || file.tempfile.nil?
  #   end
    
  #   #
  #   # Output files should store *directory* paths of output files
  #   # Need to store the final_pdf on the file server somewhere?
  #   #
  #   pdf_paths = []
  #   final_pdf = Tempfile.new(["output", ".pdf"])

  #   #
  #   # Confirm subtype categories using filemagic (exception handling
  #   # must be done outside multithreaded environment below...)
  #   #
  #   files.each do | file |
  #     logger.debug "per-file magic for {file.tempfile.path}"
  #     fm = FileMagic.new(FileMagic::MAGIC_MIME)
  #     logger.debug "post-file magic"
  #     mime = fm.file file.tempfile.path
  #     logger.debug "file mime #{mime}"

  #     case file.type
  #     when 'image'
  #       accept = ["image/png", "image/gif", "image/bmp", "image/tiff", "image/jpeg"]
  #     when 'code'
  #       accept = ["text/x-pascal", "text/x-c", "text/x-c++", "text/plain"]
  #     when 'document'
  #       accept = ["application/vnd.openxmlformats-officedocument.wordprocessingml.document",
  #                 "application/msword", "application/pdf"]
  #     else
  #       error!({"error" => "Unknown type '#{file.type}' provided for '#{file.name}'"}, 403)
  #     end
      
  #     if not mime.start_with?(*accept)
  #       error!({"error" => "'#{file.name}' was not an #{file.type} file type"}, 403)
  #     end
  #   end
    
  #   #
  #   # Convert each file concurrently... Ruby arrays are NOT thread safe, so we
  #   # must push output files to the pdf_paths array atomically
  #   #
  #   pdf_paths_mutex = Mutex.new
  #   files.each_with_index.map do | file, idx |
  #     Thread.new do         
  #       #
  #       # Create dual output documents (coverpage and document itself)
  #       #
  #       coverp_file = Tempfile.new(["#{idx}.cover", ".pdf"])
  #       output_file = Tempfile.new(["#{idx}.data", ".pdf"])
                  
  #       #
  #       # Make file coverpage
  #       #
  #       coverpage_data = { "Filename" => "<pre>#{file.filename}</pre>", "Document Type" => file.type.capitalize, "Upload Timestamp" => DateTime.now.strftime("%F %T"), "File Number" => "#{idx+1} of #{files.length}"}
  #       # Add student details if exists
  #       if not student.nil?
  #         coverpage_data["Student Name"] = student.name
  #         coverpage_data["Student ID"] = student.username
  #       end
  #       coverpage_body = "<h1>#{file.name}</h1>\n<dl>"
  #       coverpage_data.each do | key, value |
  #         coverpage_body << "<dt>#{key}</dt><dd>#{value}</dd>\n"
  #       end
  #       coverpage_body << "</dl><footer>Generated with Doubtfire</footer>"
        
  #       logger.debug "pre PDFKit"
  #       kit = PDFKit.new(coverpage_body, :page_size => 'A4', :margin_top => "30mm", :margin_right => "30mm", :margin_bottom => "30mm", :margin_left => "30mm")
  #       kit.stylesheets << "vendor/assets/stylesheets/doubtfire-coverpage.css"
  #       logger.debug "pre kit.to_file #{coverp_file.path}"
  #       kit.to_file coverp_file.path
  #       logger.debug "post PDFKit call"

  #       #
  #       # File -> PDF
  #       #  
  #       case file.type
  #       #
  #       # img -> pdf
  #       #
  #       when 'image'
  #         img = Magick::Image.read(file.tempfile.path).first
  #         # resize the image if its too big (e.g., taken with a digital camera)
  #         if img.columns > 1000 || img.rows > 500
  #           # resize such that it's 600px in width
  #           scale = 1000.0 / img.columns
  #           img = img.resize(scale)
  #         end
  #         img.write("pdf:#{output_file.path}") { self.quality = 75 }
  #       #
  #       # code -> html -> pdf
  #       #
  #       when 'code'
  #         # decide language syntax highlighting
  #         case File.extname(file.filename)
  #         when '.cpp', '.cs'
  #           lang = :cplusplus
  #         when '.c', '.h'
  #           lang = :c
  #         when '.java'
  #           lang = :java
  #         when '.pas'
  #           lang = :delphi
  #         else
  #           # should follow basic C syntax (if, else etc...)
  #           lang = :c
  #         end
          
  #         # code -> HTML
  #         html_body = CodeRay.scan_file(file.tempfile, lang).html(:wrap => :div, :tab_width => 2, :css => :class, :line_numbers => :table, :line_number_anchors => false)

  #         # HTML -> PDF
  #         kit = PDFKit.new(html_body, :page_size => 'A4', :header_left => file.filename, :header_right => "[page]/[toPage]", :margin_top => "10mm", :margin_right => "5mm", :margin_bottom => "5mm", :margin_left => "5mm")
  #         kit.stylesheets << "vendor/assets/stylesheets/coderay.css"
  #         kit.to_file output_file.path
  #       #
  #       # document -> pdf
  #       #
  #       when 'document'
  #         # if uploaded a PDF, then directly pass in
  #         if File.extname(file.filename) == '.pdf'
  #           # copy the file over (note we need to copy it into
  #           # output_file as file will be removed at the end of this block)
  #           FileUtils.cp file.tempfile.path, output_file.path
  #         else
  #         # TODO: convert word -> pdf
  #           error!({"error" => "Currently, word documents are not supported. Convert the document to PDF first."}, 403)
  #         end
  #       end
        
  #       # Insert (at appropriate index) the converted PDF and its coverpage to pdf_paths array (lock first!)...
  #       pdf_paths_mutex.synchronize do
  #         pdf_paths[idx] = [coverp_file.path, output_file.path]
  #       end
  #     end
  #   end.each { | thread | thread.join }
    
  #   pdf_paths = pdf_paths.flatten
    
  #   #
  #   # Aggregate each of the output PDFs
  #   #
  #   didCompile = system "pdftk #{pdf_paths.join ' '} cat output #{final_pdf.path}"
  #   if !didCompile 
  #     error!({"error" => "PDF failed to compile. Please try again."}, 403)
  #   end
    
  #   # We don't need any of those pdf_paths files anymore after compiling the final_pdf!
  #   pdf_paths.each { | path | if File::exist?(path) then FileUtils::rm path end } 
  #   files.each { | file | if File::exist?(file.tempfile.path) then file.tempfile.unlink end }
  #   # We need to do something with this... so we'll let the caller handle that.
  #   final_pdf
  # end
  
  # #
  # # Generates a path for storing student work
  # #
  # def student_work_dir(unit, student, task)
  #   file_server = Doubtfire::Application.config.student_work_dir
  #   dst = "#{file_server}/#{unit.code}-#{unit.id}/#{student.username}/#{task.task_definition.abbreviation}.pdf"
  #   # Make that directory should it not exist
  #   FileUtils.mkdir_p(File.dirname(dst))
  #   dst
  # end
  
  #
  # Defines the csv headers for batch download
  #
  def mark_csv_headers
    "Username,Name,Task,ID,ready_to_mark (rtm)|discuss (d)|fix_and_resubmit (fix)|fix_and_include (fixinc)|redo"
  end
  
  
  #
  # Generates a download package of the given tasks
  #
  def generate_batch_task_zip(tasks, unit)
    download_id = "#{Time.new.strftime("%Y-%m-%d")}-#{unit.code}-#{current_user.username}"
    output_zip = Tempfile.new(["batch_ready_to_mark_#{current_user.username}", ".zip"])
    # Create a new zip
    Zip::File.open(output_zip.path, Zip::File::CREATE) do | zip |
      csv_str = mark_csv_headers
      tasks.each  do | task |
        # Skip tasks that do not yet have a PDF generated
        next if task.processing_pdf
        # Add to the template entry string
        student = task.project.student
        csv_str << "\n#{student.username},#{student.name},#{task.task_definition.abbreviation},#{task.id},rtm"
        src_path = task.portfolio_evidence
        # make dst path of "<student id>/<task abbrev>.pdf"
        dst_path = "#{task.project.student.username}/#{task.task_definition.abbreviation}-#{task.id}.pdf"
        # now copy it over
        zip.add(dst_path, src_path)
      end
      # Add marking file
      zip.get_output_stream("marks.csv") { | f | f.puts csv_str }
    end
    output_zip
  end  

  #
  # Uploads a batch package back into doubtfire
  #
  def upload_batch_task_zip(file)
    updated_tasks = []
    # check mime is correct before uploading
    if not %w(application/zip multipart/x-gzip multipart/x-zip application/x-gzip application/octet-stream).include? file.type
      error!({"error" => "File given is not a zip file"}, 403)
    end
    Zip::File.open(file.tempfile.path) do |zip|
      # Process the marking file
      marking_file = zip.glob("marks.csv").first
      if marking_file.nil?
        error!({"error" => "No marks.csv contained in zip"}, 403)
      end
      csv_str = marking_file.get_input_stream.read
      keys = mark_csv_headers.split(',').map { | s | s.downcase }
      keys[keys.length-1] = "mark" #rename the big string to just mark
      entry_data = CSV.parse(csv_str).map { | a | Hash[ keys.zip(a) ] }
      entry_data.shift #remove header rows
      # Copy over the updated/marked files to the file system
      zip.each do |file|
        # Skip processing marking file
        next if file.name == "marks.csv"
        # Extract the id from the filename
        task_id_from_filename = File.basename(file.name, ".pdf").split('-').last
        task = Task.find_by_id(task_id_from_filename)
        next if task.nil?
        # Ensure that this task's id is inside entry_data
        task_entry = entry_data.select{ | t | t['id'] == task.id.to_s }.first
        if task_entry.nil?
          error!({"error" => "File #{file.name} has a mismatch of task id ##{task.id} (this task id does not exist in marks.csv)"}, 403)
        end
        # Ensure that this task's student matches that in entry_data
        if task_entry['username'] != task.project.student.username
          error!({"error" => "File #{file.name} has a mismatch of student id (task with id #{task.id} matches student #{task.project.student.username}, not that in marks.csv of #{t['id']}"}, 403)
        end
        
        # Update the task to whatever its associative mark was 
        valid_marks = %w(ready_to_mark rtm redo fix_and_resubmit fix fix_and_include fixinc discuss d)
        if task_entry['mark'].nil? or not valid_marks.include? task_entry['mark'].strip
          msg = task_entry['mark'].nil? ? "it is missing a mark value in marks.csv" : "acceptable mark codes: #{valid_marks.join ' '}"
          error!({"error" => "Task id #{task.id} has an invalid mark (#{msg})"}, 403)
        end
        
        # Read into the task's portfolio_evidence path the new file
        file.extract(task.portfolio_evidence){ true }
        
        task.trigger_transition(task_entry['mark'], current_user)
        updated_tasks << task
      end
    end
    updated_tasks
  end
  
  # module_function :combine_to_pdf
  module_function :scoop_files
  module_function :upload_batch_task_zip
  module_function :generate_batch_task_zip
  
end