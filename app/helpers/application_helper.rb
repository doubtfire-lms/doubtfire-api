module ApplicationHelper
  def javascript(*files)
    content_for(:javascript) { javascript_include_tag(*files) }
  end

  def stylesheets(*files)
    content_for(:css) { stylesheet_link_tag(*files) }
  end
end