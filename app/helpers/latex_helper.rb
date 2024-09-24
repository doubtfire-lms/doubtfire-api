module LatexHelper
  def generate_pdf(template:)
    raise 'LATEX_CONTAINER_NAME is not set' if ENV['LATEX_CONTAINER_NAME'].nil?
    raise 'LATEX_BUILD_PATH is not set' if ENV['LATEX_BUILD_PATH'].nil?
    render_to_string(template: template, layout: true)
  end
end
