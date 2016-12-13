class DoubtfireLogger < ActiveSupport::Logger
  # By default, nil is provided
  #
  # Arguments match:
  #   1. logdev - filename or IO object (STDOUT or STDERR)
  #   2. shift_age - number of files to keep, or age (e.g., monthly)
  #   3. shift_size - maximum log file size (only used when shift_age)
  #                   is a number
  #
  # Rails.logger initialises these as nil, so we will do the same
  @@logger = DoubtfireLogger.new(Doubtfire::Application.config.paths['log'].first)

  #
  # Singleton logger returned
  #
  def self.logger
    @@logger
  end

  #
  # Override fatal and error to puts to the console
  # as well as log using Rails
  #
  def fatal(msg)
    puts msg
    super(msg)
  end

  def error(msg)
    puts msg
    super(msg)
  end
end
