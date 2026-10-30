module LatexHelper
  LATEX_ASSET_IMAGE_PATH = '/doubtfire/public/assets/images'.freeze

  attr_reader :work_id

  def generate_pdf(template:)
    raise 'LATEX_CONTAINER_NAME is not set' if ENV['LATEX_CONTAINER_NAME'].nil?
    raise 'LATEX_BUILD_PATH is not set' if ENV['LATEX_BUILD_PATH'].nil?

    yield if block_given?
    render_to_string(template: template, layout: true)
  ensure
    FileUtils.rm_rf(latex_work_dir) if work_id.present?
  end

  def stage_latex_file(source_path)
    raise ArgumentError, "Not a regular file: #{source_path}" unless File.file?(source_path) && !File.symlink?(source_path)

    extension = File.extname(source_path).downcase.gsub(/[^.a-z0-9]/, '_')
    relative_path = File.join('inputs', "#{SecureRandom.hex(12)}#{extension}")
    destination = latex_work_dir.join(relative_path)
    FileUtils.mkdir_p(destination.dirname)
    FileUtils.cp(source_path, destination)
    relative_path
  end

  def latex_host_path(relative_path)
    latex_work_dir.join(relative_path)
  end

  private

  def latex_work_dir
    Rails.root.join('tmp', 'rails-latex', work_id, 'work')
  end
end
