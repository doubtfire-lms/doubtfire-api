require "active_support/core_ext/hash/indifferent_access"

# lib/tasks/simulate_jplag_submissions.rake
namespace :db do
  desc 'Simulate submissions to test with JPlag'
  task simulate_jplag_submissions: [:skip_prod, :environment] do
    Rails.logger.level = Logger::INFO
    puts "Setting up submissions to test with JPlag..."

    unit = Unit.first
    unless unit
      puts "No units found!"
      next
    end

    target_date = unit.start_date + 12.weeks # Assignment 6 due week 6, etc.
    start_date = target_date - Faker::Number.between(from: 1.0, to: 2.0).weeks

    puts "Creating task definition"

    task_def = TaskDefinition.find_by(abbreviation: "java-1")

    if task_def.nil?
      task_def = TaskDefinition.create!(
        name: "Java Fundamentals",
        abbreviation: "java-1",
        unit_id: unit.id,
        tutorial_stream: unit.tutorial_streams.first,
        description: faker_random_sentence(5, 10),
        weighting: BigDecimal("2"),
        target_date: target_date,
        upload_requirements: [
          {
            key: "file0",
            name: "Java code file",
            type: "code",
            tii_check: true
          }
        ],
        start_date: start_date,
        target_grade: "0",
        similarity_language: "java"
      )
    end

    task_def.update(plagiarism_warn_pct: 10)

    student_count = 0
    # random_campus = Campus.find(Campus.pluck(:id).sample)

    tutorial = unit.tutorials.first

    if tutorial.nil?
      puts "Nil tutorial"
      return
    end

    random_campus = tutorial.campus

    ui = Class.new do
      def error!(hash, status)
        raise "#{status}: #{hash[:error] || hash['error']}"
      end
    end.new

    5.times do
      student = find_or_create_student("student_#{student_count}")
      project = unit.enrol_student(student, random_campus)
      student_count += 1
      # project.enrol_in(tutorial)

      jplag_dir = "test_files/submissions/jplag"
      random_dir = Dir.children(jplag_dir).select { |f| File.directory?(File.join(jplag_dir, f)) }.sample
      java_file = Dir.glob(File.join(jplag_dir, random_dir, "*.java")).first

      task = project.task_for_task_definition(task_def)

      files = [
        {
          id: "file0",
          name: "Javacodefile.java",
          type: "code",
          filename: File.basename(java_file),
          "tempfile" => Tempfile.new([File.basename(java_file, ".java"), ".java"]).tap do |f|
            f.write(File.read(java_file))
            f.rewind
          end
        }.with_indifferent_access
      ]

      task.accept_submission(student, files, ui, nil, 'ready_for_feedback', nil)
      task.convert_submission_to_pdf(log_to_stdout: false)
    end

    unit.check_jplag_similarity(force: true)
    # $: rake submission:check_plagiarism
  end
end
