module ApplicationHelper
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