module ApplicationHelper
  def reference_date
    @@reference_date ||= if Doubtfire::Application::config.respond_to? :reference_date
      Time.zone.parse(Doubtfire::Application::config.reference_date)
    else
      Time.zone.now
    end
  end

  def flash_class(level)
    case level
    when :notice  then "info"
    when :error   then "error"
    when :alert   then "warning"
    end
  end

  def javascript(*files)
    content_for(:javascript) { javascript_include_tag(*files) }
  end

  def stylesheets(*files)
    content_for(:css) { stylesheet_link_tag(*files) }
  end
end