# lib/tasks/setup_jplag_submissions.rake
namespace :db do
  desc 'Setup submissions to test with JPlag'
  task setup_jplag_submissions: [:environment] do
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

    student_count = 0
    random_campus = Campus.find(Campus.pluck(:id).sample)

    tutorial = unit.tutorials.first

    if tutorial.nil?
      puts "Nil tutorial"
      return
    end

    ui = Class.new do
      def error!(hash, status)
        raise "#{status}: #{hash[:error] || hash['error']}"
      end
    end.new

    20.times do
      student = find_or_create_student("student_#{student_count}")
      project = unit.enrol_student(student, random_campus)
      student_count += 1
      project.enrol_in(tutorial)

      jplag_dir = "test_files/submissions/jplag"
      random_dir = Dir.children(jplag_dir).select { |f| File.directory?(File.join(jplag_dir, f)) }.sample
      java_file = Dir.glob(File.join(jplag_dir, random_dir, "*.java")).first

      task = project.task_for_task_definition(task_def)

      # TODO: automate task submission
      # files = [
      #   {
      #     id: "SomeFile.java",
      #     name: "Java code file",
      #     type: "code",
      #     filename: File.basename(java_file),
      #     tempfile: File.open(java_file)
      #   }
      # ]

      # task.accept_submission(student, files, ui, nil, nil, nil)

      # task.convert_submission_to_pdf(log_to_stdout: false)
      echo '.'
    end

    unit.check_jplag_similarity

    puts "JPLAG submissions setup complete."
  end
end
