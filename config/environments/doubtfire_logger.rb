class DoubtfireLogger
  # By default, nil is provided
  #
  # Arguments match:
  #   1. logdev - filename or IO object (STDOUT or STDERR)
  #   2. shift_age - number of files to keep, or age (e.g., monthly)
  #   3. shift_size - maximum log file size (only used when shift_age)
  #                   is a number
  #
  # Rails.logger initialises these as nil, so we will do the same
  @@file_logger = ActiveSupport::Logger.new(Doubtfire::Application.config.paths['log'].first)
  @@console_logger = ActiveSupport::Logger.new(STDOUT)

  @@logger = @@console_logger.extend(ActiveSupport::Logger.broadcast(@@file_logger))

  @@logger.formatter = proc do |severity, datetime, progname, msg|
    "#{datetime},#{DoubtfireLogger.remote_ip},#{severity}: #{msg}\n"
  end

  def self.remote_ip
    Thread.current.thread_variable_get(:ip) || 'unknown'
  end

  #
  # Singleton logger returned
  #
  def self.logger
    @@logger
  end
end
