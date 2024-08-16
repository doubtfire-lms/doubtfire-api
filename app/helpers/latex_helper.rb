module LatexHelper
  def generate_pdf(template:, unique_render_id:)
    container_name = ENV.fetch('LATEX_CONTAINER_NAME', nil)
    latex_build_path = ENV.fetch('LATEX_BUILD_PATH', nil)

    logger.debug "Running make_pdf: (#{template})"

    # Render the portfolio layout
    tex_string = render_to_string(template: template, layout: true)

    # Create a new working directory to save input.tex into
    workdir_name = "#{unique_render_id}-#{Process.pid}-#{Thread.current.hash}"
    workdir = Rails.root.join("tmp", "texlive-latex", workdir_name)
    FileUtils.mkdir_p(workdir)

    # Copy jupynotex.py over into the working directory
    FileUtils.cp(Rails.root.join('app', 'views', 'layouts', 'jupynotex.py'), workdir)

    # Save tex_string as input.tex into the workdir
    File.open(workdir.join("input.tex"), 'w') do |fout|
      fout.puts tex_string
    end

    # Docker command to execute the build script in texlive container
    command = "sudo docker exec -it #{container_name} #{latex_build_path} #{workdir_name}"

    Process.waitpid(
      fork do
        logger.debug "Executing system command: #{command}"

        # Execute the Docker command
        clean_exit = system(command)
        Process.exit!(1) unless clean_exit
      rescue StandardError
        logger.info "PDF Generation failed: #{clean_exit}"
      ensure
        Process.exit!(0) if clean_exit
      end
    )

    status = $?.exitstatus

    if status == 0 && File.exist?(File.join(workdir, "input.pdf"))
      # Read the generated PDF file and return it as a string
      pdf_string = File.read(workdir.join("input.pdf"))

      # Delete temporary workdir containing input.tex/input.pdf and logs
      FileUtils.rm_rf(workdir)
    else
      raise "PDF Generation failed. See tmp/texlive-latex/#{workdir_name}/input.log for details."
    end

    pdf_string
  end
end
