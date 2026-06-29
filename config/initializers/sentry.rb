module OnTrackSentryRedaction
  FILTERED = "[Filtered]".freeze
  PII_KEY_PATTERN = /(^|_)(email|first_name|last_name|login_id|name|student_id|username|user_id)\z/i
  RAILS_LATEX_TASK_WORK_DIR = %r{(tmp/rails-latex/task-\d{8}-\d{4}-)[^/\s]+?(-[^/\s-]+-\d+-\d+(?:-retry)?)(?=/|\s|$)}
  RAILS_LATEX_PORTFOLIO_WORK_DIR = %r{(tmp/rails-latex/portfolio-\d{8}-\d{4}-)[^/\s]+?(-\d+-\d+(?:-retry)?)(?=/|\s|$)}
  SCORM_PATH = %r{(/scorm/[^/?#]+/)[^/?#]+(/)[^/?#]+}i

  module_function

  def scrub_event(event)
    scrub_request(event.request) if event.respond_to?(:request)

    event.message = scrub_string(event.message) if event.respond_to?(:message) && event.respond_to?(:message=)
    event.user.replace(scrub_hash(event.user)) if event.respond_to?(:user) && event.user.respond_to?(:replace)
    event.extra.replace(scrub_hash(event.extra)) if event.respond_to?(:extra) && event.extra.respond_to?(:replace)

    scrub_exception(event.exception) if event.respond_to?(:exception)
    scrub_breadcrumbs(event.breadcrumbs) if event.respond_to?(:breadcrumbs)

    event
  end

  def scrub_request(request)
    return unless request

    request.url = scrub_string(request.url) if request.respond_to?(:url) && request.respond_to?(:url=)
    request.headers&.each_key do |key|
      request.headers[key] = FILTERED if key.casecmp("Username").zero?
    end
  end

  def scrub_exception(exception)
    exception&.each_value do |value|
      value.value = scrub_string(value.value) if value.respond_to?(:value) && value.respond_to?(:value=)

      next unless value.respond_to?(:stacktrace)

      value.stacktrace&.frames&.each do |frame|
        %i[abs_path context_line filename function module pre_context post_context vars].each do |attribute|
          next unless frame.respond_to?(attribute) && frame.respond_to?(:"#{attribute}=")

          frame.public_send(:"#{attribute}=", scrub_value(frame.public_send(attribute)))
        end
      end
    end
  end

  def scrub_breadcrumbs(breadcrumbs)
    breadcrumbs&.each do |breadcrumb|
      breadcrumb.message = scrub_string(breadcrumb.message) if breadcrumb.respond_to?(:message) && breadcrumb.respond_to?(:message=)
      breadcrumb.data = scrub_hash(breadcrumb.data) if breadcrumb.respond_to?(:data) && breadcrumb.respond_to?(:data=)
    end
  end

  def scrub_value(value)
    case value
    when Hash
      scrub_hash(value)
    when Array
      value.map { |item| scrub_value(item) }
    when String
      scrub_string(value)
    else
      value
    end
  end

  def scrub_hash(hash)
    hash.each_with_object({}) do |(key, value), result|
      key = key.to_s
      result[key] = key.match?(PII_KEY_PATTERN) ? FILTERED : scrub_value(value)
    end
  end

  def scrub_string(value)
    return value unless value.is_a?(String)

    value
      .gsub(RAILS_LATEX_TASK_WORK_DIR, "\\1[username]\\2")
      .gsub(RAILS_LATEX_PORTFOLIO_WORK_DIR, "\\1[username]\\2")
      .gsub(SCORM_PATH, "\\1[username]\\2[Filtered]")
  end
end

if ENV["SENTRY_DSN"].present?
  Sentry.init do |config|
    config.dsn = ENV.fetch("SENTRY_DSN", nil)
    # Rails log breadcrumbs are excluded because app logs can include user details.
    config.breadcrumbs_logger = [:http_logger]
    config.environment = ENV.fetch("SENTRY_ENVIRONMENT", Rails.env)
    config.release = ENV["SENTRY_RELEASE"] if ENV["SENTRY_RELEASE"].present?
    # Add data like request headers and IP for users, if applicable;
    # see https://docs.sentry.io/platforms/ruby/data-management/data-collected/ for more info
    config.send_default_pii = false

    config.before_send = lambda do |event, _hint|
      OnTrackSentryRedaction.scrub_event(event)
    end
  end
end
