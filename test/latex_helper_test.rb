require 'test_helper'
require 'tempfile'

class LatexHelperTest < ActiveSupport::TestCase
  def test_staged_inputs_are_copies_and_are_removed_after_rendering
    source = Tempfile.new(['latex-source-', '.pdf'])
    source.binmode
    source.write('original student file')
    source.flush

    work_id = "latex-staging-test-#{SecureRandom.hex(8)}"
    renderer = Object.new.extend(LatexHelper)
    renderer.instance_variable_set(:@work_id, work_id)
    renderer.define_singleton_method(:render_to_string) { |**_options| 'rendered PDF' }
    latex_env = ENV.values_at('LATEX_CONTAINER_NAME', 'LATEX_BUILD_PATH')
    ENV['LATEX_CONTAINER_NAME'] ||= 'test-texlive'
    ENV['LATEX_BUILD_PATH'] ||= '/test/latex_build.sh'

    staged_path = nil
    result = renderer.generate_pdf(template: 'unused') do
      relative_path = renderer.stage_latex_file(source.path)
      staged_path = renderer.latex_host_path(relative_path)
      assert_kind_of String, staged_path
      assert_equal 'original student file', File.binread(staged_path)
      File.binwrite(staged_path, 'changed copy')
      assert_equal 'original student file', File.binread(source.path)
    end

    assert_equal 'rendered PDF', result
    assert_not File.exist?(staged_path)
    assert_equal 'original student file', File.binread(source.path)

    renderer.define_singleton_method(:render_to_string) { |**_options| raise 'render failed' }
    assert_raises(RuntimeError) do
      renderer.generate_pdf(template: 'unused') do
        staged_path = renderer.latex_host_path(renderer.stage_latex_file(source.path))
      end
    end
    assert_not File.exist?(staged_path)
    assert_equal 'original student file', File.binread(source.path)
  ensure
    if latex_env
      ENV['LATEX_CONTAINER_NAME'], ENV['LATEX_BUILD_PATH'] = latex_env
    end
    source&.close!
    FileUtils.rm_rf(Rails.root.join('tmp', 'rails-latex', work_id)) if work_id
  end
end
