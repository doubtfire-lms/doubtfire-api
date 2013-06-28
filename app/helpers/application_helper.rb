  module ApplicationHelper
  def application_reference_date
    @@application_reference_date ||= if Doubtfire::Application::config.respond_to? :application_reference_date
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

  # Generates a tab content tag (<div class="tab-pane active"> or <div class="tab-pane">) depending on whether the "tab" page param matches a given identifier.
  # Useful for redirecting to a specific tab within a view.
  # @param id      - the id of the tab pane
  # @param default - whether this tab is the 'default' - if no tab param is passed in the page url, the default tab will be activated.
  # @param &block  - whatever html/erb code falls between <%= tab_li_tag("tab-identifier") %> and <% end %>.
  def tab_div_tag(id, default = false, &block)
    content = capture(&block)
    content_tag(:div, content, id:  id, class:  "#{
      if params[:tab] == id or (default and !params[:tab]) then
        'tab-pane active'
      else
        'tab-pane'
      end
    }")
  end

  # Generates a tab header tag (<li> or <li class="active">) depending on whether the "tab" page param matches a given identifier.
  # Useful for redirecting to a specific tab within a view.
  # @param id      - the id of the tab pane
  # @param default - whether this tab is the 'default' - if no tab param is passed in the page url, the default tab will be activated.
  # @param &block  - whatever html/erb code falls between <%= tab_li_tag("tab-identifier") %> and <% end %>.
  def tab_li_tag(id, default = false, &block)
    content = capture(&block)
    content_tag(:li, content, class:  "#{'active' if params[:tab] == id or (default and !params[:tab])}")
  end

  # Generates a tab dropdown tag (<li class="dropdown active"> or <div class="dropdown">) depending on whether the "tab" page param matches a given identifier.
  # Useful for redirecting to a specific tab within a view.
  # @param ids     - collection of tab ids that are children of the dropdown
  # @param default - whether this tab is the 'default' - if no tab param is passed in the page url, the default tab will be activated.
  # @param &block  - whatever html/erb code falls between <%= tab_li_tag("tab-identifier") %> and <% end %>.
  def tab_dropdown_tag(ids, default = false, &block)
    content = capture(&block)
    content_tag(:li, content, class:  "#{
      if ids.include?(params[:tab]) or (default and !params[:tab]) then
        'dropdown active'
      else
        'dropdown'
      end
    }")
  end

  def sortable(column, title = nil)
    title ||= column.titleize

    link = if column == sort_column
      sort_icon = sort_direction == "asc" ? '<i class="icon-sort-down"></i>' : '<i class="icon-sort-up"></i>'
      raw("#{title} #{sort_icon}")
    else
      title
    end

    css_class = column == sort_column ? "current #{sort_direction}" : nil
    direction = column == sort_column && sort_direction == "asc" ? "desc" : "asc"

    link_to link,
      params.merge(
        sort: column,
        direction: direction
      ),
      {class:  css_class}
  end
end