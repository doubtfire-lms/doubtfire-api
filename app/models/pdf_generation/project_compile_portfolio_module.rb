module PdfGeneration
  module ProjectCompilePortfolioModule
    def projects_awaiting_auto_generation
      Project.joins(:unit)
             .where(units: { active: true, end_date: Date.today..Float::INFINITY })
             .where(projects: { enrolled: true, portfolio_production_date: nil })
             .where("units.portfolio_auto_generation_date < ?", Date.today)
             .where(compile_portfolio: false)
             .reject(&:portfolio_available)
    end

    module_function :projects_awaiting_auto_generation

    # Automatically generate the portfolio for this project - only when the
    # learning summary exists, the project is enrolled, and the portfolio is not
    # already available.
    def auto_generate_portfolio
      # Check we have a draft learning summary report
      return false unless enrolled && learning_summary_report_exists? && !portfolio_available

      # Flag compile is needed
      self.compile_portfolio = true
      # Assign current target as anticipated target grade
      self.submitted_grade = self.target_grade
      # Inidicate this is an auto-generated portfolio
      self.portfolio_auto_generated = true
      # Save changes
      self.save
    end

    # Compress the student's portfolio if larger than 20mb
    def compress_portfolio
      FileHelper.compress_pdf(portfolio_path, max_size: 20_000_000, timeout_seconds: 120)
    end

    # This class scaffolds the creation of the portfolio - mapping the required data into the erb template
    class ProjectAppController < ApplicationController
      attr_accessor :student,
                    :project,
                    :base_path,
                    :image_path,
                    :learning_summary_report,
                    :ordered_tasks,
                    :portfolio_tasks,
                    :task_defs,
                    :outcomes,
                    :files,
                    :institution_name,
                    :doubtfire_product_name,
                    :is_retry

      def init(project, is_retry)
        @student = project.student
        @project = project
        @learning_summary_report = project.learning_summary_report_path
        @files = project.portfolio_files(ensure_valid: true, force_ascii: is_retry)
        @base_path = project.portfolio_temp_path
        @image_path = Rails.root.join('public', 'assets', 'images')
        @ordered_tasks = project.tasks.joins(:task_definition).order('task_definitions.start_date, task_definitions.abbreviation').where("task_definitions.target_grade <= #{project.target_grade}")
        @portfolio_tasks = project.portfolio_tasks
        @task_defs = project.unit.task_definitions.order(:start_date)
        @outcomes = project.unit.learning_outcomes.order(:ilo_number)
        @institution_name = Doubtfire::Application.config.institution[:name]
        @doubtfire_product_name = Doubtfire::Application.config.institution[:product_name]
        @is_retry = is_retry
      end

      def make_pdf
        logger.debug "Running make_pdf: (portfolio)"

        # Render the portfolio layout
        tex_string = render_to_string(template: '/portfolio/portfolio_pdf', layout: true)

        # Create a new working directory to save input.tex into
        workdir_name = "#{Process.pid}-#{Thread.current.hash}"
        workdir = Rails.root.join("tmp", "texlive-latex", workdir_name)
        FileUtils.mkdir_p(workdir);

        # Copy jupynotex.py over into the working directory
        FileUtils.cp(Rails.root.join('app', 'views', 'layouts', 'jupynotex.py'), workdir)

        # Save tex_string as input.tex into the workdir
        File.open(workdir.join("input.tex"), 'w') do |fout|
          fout.puts tex_string
        end

        # TODO: clean up pathnames
        container_name = "1-formatif-texlive-container"
        latex_build_path = "/texlive/shell/latex-build.sh" # mounted path on the texlive container, as defined in .devcontainer/docker-compose.yml
        latex_pdf_output_dir = workdir_name
        latex_input_file_path = File.join(workdir_name, "input.tex")

        # Docker command to execute the build script in texlive container
        command = "sudo docker exec -it #{container_name} #{latex_build_path} #{latex_pdf_output_dir} #{latex_input_file_path}"

        logger.debug "Executing system command: #{command}"

        success = nil
        Process.waitpid(
          fork do
            begin
              # Execute the Docker command
              success = system(command)
              Process.exit! 1 unless success
            rescue
              logger.info "PDF Generation failed: #{success}"
            ensure
              Process.exit! 1
            end
          end
        )

        # TODO: verify that input.pdf now exists in the workdir, otherwise throw error

        # unless success
        #   logger.error "Docker command failed: #{command}"
        #   return "Error generating PDF"
        # end

        # Read the generated PDF file and return it as a string
        pdf_string = File.read(workdir.join("input.pdf"))

        # Delete temporary workdir containing input.tex/input.pdf and logs
        # FileUtils.rm_rf(workdir) 

        pdf_string
      end

    end

    # Create the portfolio for this project
    def create_portfolio
      self.compile_portfolio = false
      save!

      begin
        pac = ProjectAppController.new
        pac.init(self, false)

        begin
          pdf_text = pac.make_pdf
        rescue StandardError => e
          # Clear the old text
          pdf_text = nil

          # Try again... with convert to ascii
          pac2 = ProjectAppController.new
          pac2.init(self, true)

          pdf_text = pac2.make_pdf
        end

        File.open(portfolio_path, 'w') do |fout|
          fout.puts pdf_text
        end

        compress_portfolio

        logger.info "Created portfolio at #{portfolio_path} - #{log_details}"

        self.portfolio_production_date = Time.zone.now
        save
      rescue StandardError => e
        logger.error "Failed to convert portfolio to PDF - #{log_details} -\nError: #{e.message}"

        log_file = e.message.scan(%r{/.*\.log}).first
        if log_file && File.exist?(log_file)
          begin
            puts "--- Latex Log ---\n"
            puts File.read(log_file)
            puts "---    End    ---\n\n"
          rescue StandardError
            puts "Failed to read log file: #{log_file}"
          end
        end
        false
      end
    end

    def save_as_learning_summary_report(path)
      file_name = {
        kind: 'document',
        name: 'LearningSummaryReport.pdf',
        idx: 0
      }
      # Creates tmp portfolio path (if it doesn't exist)
      FileUtils.mkdir_p(portfolio_temp_path)

      # Copy the file into place
      FileUtils.cp path, portfolio_tmp_file_path(file_name)

      # Record we are using the draft learning summary and save
      self.uses_draft_learning_summary = true
      self.save
    end

    # Return the tasks to include in the student's portfolio
    def portfolio_tasks
      # Get assigned tasks that are included in the portfolio
      tasks = self.tasks.joins(:task_definition).order('task_definitions.target_date, task_definitions.abbreviation').where('tasks.include_in_portfolio = TRUE')

      # Now select the tasks that and have a PDF... cant include the others...
      tasks.select(&:has_pdf)
    end

    #
    # Return the path to the student's learning summary report.
    # This returns nil if there is no learning summary report.
    #
    def learning_summary_report_path
      # Cache the portfolio temp path
      portfolio_tmp_dir = portfolio_temp_path

      return nil unless Dir.exist? portfolio_tmp_dir

      filename = "#{portfolio_tmp_dir}/000-document-LearningSummaryReport.pdf"
      return nil unless File.exist? filename

      filename
    end

    # Check if the learning summary report exists
    #
    # @return [Boolean] true if the learning summary report file exists for this project
    def learning_summary_report_exists?
      path = learning_summary_report_path
      path.present? && File.exist?(learning_summary_report_path)
    end

    #
    # Portfolio production code
    #
    def portfolio_temp_path
      portfolio_dir = FileHelper.student_portfolio_dir(self.unit, self.student.username, false)
      portfolio_tmp_dir = File.join(portfolio_dir, 'tmp')
    end

    def portfolio_tmp_file_name(dict)
      extn = File.extname(dict[:name])
      name = File.basename(dict[:name], extn)
      name = name.tr('.', '_') + extn
      FileHelper.sanitized_filename("#{dict[:idx].to_s.rjust(3, '0')}-#{dict[:kind]}-#{name}")
    end

    def portfolio_tmp_file_path(dict)
      File.join(portfolio_temp_path, portfolio_tmp_file_name(dict))
    end

    def move_to_portfolio(file, name, kind)
      # get path to portfolio dir
      # get path to tmp folder where file parts will be stored
      portfolio_tmp_dir = portfolio_temp_path
      FileUtils.mkdir_p(portfolio_tmp_dir)
      result = {
        kind: kind,
        name: file[:filename]
      }

      # copy up the learning summary report as first -- otherwise use files to determine idx
      if name == 'LearningSummaryReport' && kind == 'document'
        result[:idx] = 0
        result[:name] = 'LearningSummaryReport.pdf'

        # set uses_draft_learning_summary to false, since we uploaded a new learning summary
        self.uses_draft_learning_summary = false
        save
      else
        Dir.chdir(portfolio_tmp_dir)
        files = Dir.glob('*')
        idx = files.map { |a_file| a_file.split('-').first.to_i }.max
        if idx.nil? || idx < 1
          idx = 1
        else
          idx += 1
        end
        result[:idx] = idx
      end

      dest_file = portfolio_tmp_file_name(result)
      FileUtils.cp file["tempfile"].path, File.join(portfolio_tmp_dir, dest_file)
      result
    end

    def portfolio_files(ensure_valid: false, force_ascii: false)
      # get path to portfolio dir
      portfolio_tmp_dir = portfolio_temp_path
      return [] unless Dir.exist? portfolio_tmp_dir

      result = []

      Dir.chdir(portfolio_tmp_dir)
      files = Dir.glob('*').select { |f| (f =~ /^\d{3}-(cover|document|code|image)/) == 0 }
      files.each do |file|
        parts = file.split('-')
        idx = parts[0].to_i
        kind = parts[1]
        name = parts.drop(2).join('-')
        result << { kind: kind, name: name, idx: idx }

        FileHelper.ensure_utf8_code(file, force_ascii) if ensure_valid && kind == "code"
      end

      result
    end

    # Remove a file from the portfolio tmp folder
    def remove_portfolio_file(idx, kind, name)
      # get path to portfolio dir
      portfolio_tmp_dir = portfolio_temp_path
      return unless Dir.exist? portfolio_tmp_dir

      # the file is in the students portfolio tmp dir
      rm_file = File.join(
        portfolio_tmp_dir,
        FileHelper.sanitized_filename("#{idx.to_s.rjust(3, '0')}-#{kind}-#{name}")
      )

      # try to remove the file
      begin
        FileUtils.rm_f rm_file
      rescue StandardError
        logger.error "Failed to remove file #{rm_file} from portfolio tmp folder #{portfolio_tmp_dir}"
      end
    end

    def portfolio_path
      FileHelper.student_portfolio_path(self.unit, self.student.username, true)
    end

    def portfolio_exists?
      portfolio_production_date.present? && portfolio_available
    end

    def portfolio_status
      if portfolio_exists?
        'YES'
      elsif compile_portfolio
        'in process'
      else
        'no'
      end
    end

    def portfolio_available
      (File.exist? portfolio_path) && !compile_portfolio
    end

    def remove_portfolio
      portfolio = portfolio_path
      FileUtils.mv portfolio, "#{portfolio}.old" if File.exist?(portfolio)
    end
  end
end
