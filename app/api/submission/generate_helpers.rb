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
        csv_str << "\n#{student.username.sub(/,/, '_')},#{student.name.sub(/,/, '_')},#{task.task_definition.abbreviation.sub(/,/, '_')},#{task.id},rtm"
        src_path = task.portfolio_evidence
        # make dst path of "<student id>/<task abbrev>.pdf"
        dst_path = PortfolioEvidence.sanitized_path("#{task.project.student.username}", "#{task.task_definition.abbreviation}-#{task.id}") + ".pdf"
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
    fm = FileMagic.new(FileMagic::MAGIC_MIME)

    updated_tasks = []

    mime_type = fm.file(file.tempfile.path)

    # check mime is correct before uploading
    accept = ['application/zip', 'multipart/x-gzip', 'multipart/x-zip', 'application/x-gzip', 'application/octet-stream']
    if not mime_type.start_with?(*accept)
      error!({"error" => "File given is not a zip file - detected #{mime_type}"}, 403)
    end

    begin
      Zip::File.open(file.tempfile.path) do |zip|
        # Find the marking file within the directory tree
        marking_file = zip.glob("**/marks.csv").first
        # No marking file found
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
          task.portfolio_evidence = PortfolioEvidence.final_pdf_path_for(task)
          file.extract(task.portfolio_evidence){ true }
          
          task.trigger_transition(task_entry['mark'], current_user)
          updated_tasks << task
        end
      end
    rescue
      # FileUtils.cp(file.tempfile.path, Doubtfire::Application.config.student_work_dir)
      raise
    end
    updated_tasks
  end
  
  # module_function :combine_to_pdf
  module_function :scoop_files
  module_function :upload_batch_task_zip
  module_function :generate_batch_task_zip
  
end