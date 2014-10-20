module FileHelper

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
end
