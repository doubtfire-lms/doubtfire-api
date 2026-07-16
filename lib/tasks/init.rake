require 'io/console'

namespace :db do
  def prompt_for_admin_password
    console = IO.console
    raise 'An interactive terminal is required to set the initial admin password' if console.nil?

    loop do
      password = console.getpass('Enter password for the initial admin account: ')
      confirmation = console.getpass('Confirm password: ')

      raise 'Password entry was cancelled' if password.nil? || confirmation.nil?

      unless Devise.password_length.cover?(password.length)
        puts "Password must be #{Devise.password_length} characters long."
        next
      end

      return password if password == confirmation

      puts 'Passwords do not match. Try again.'
    end
  end

  #
  # Generate roles
  #
  def generate_user_roles
    return if Role.count > 0

    puts "-> Generating user roles"
    roles = [
      { name: 'Student', description: "Students are able to be enrolled into units, and to submit progress for their unit projects." },
      { name: 'Tutor', description: "Tutors are able to supervise tutorial classes and provide feedback to students, they may also be students in other units" },
      { name: 'Convenor', description: "Convenors are able to create and manage units, as well as act as tutors and students." },
      { name: 'Admin', description: "Admin are able to create convenors, and act as convenors, tutors, and students in units." },
      { name: 'Auditor', description: "Auditors are able to view only everything an admin can." }
    ]

    roles.each do |role|
      Role.create!(name: role[:name], description: role[:description])
      print "."
    end
    puts "!"
  end

  #
  # Generate tasks statuses
  #
  def generate_task_statuses
    return if TaskStatus.db_count > 0

    puts "-> Generating task statuses"
    statuses = {
      "Not Started": "You have not yet started this task.",
      Complete: "This task has been signed off by your tutor.",
      "Need Help": "Some help is required in order to complete this task.",
      "Working On It": "This task is currently being worked on.",
      "Fix and Resubmit": "This task must be resubmitted after fixing some issues.",
      "Feedback Exceeded": "This task must be fixed and included in your portfolio, but no additional feedback will be provided.",
      Redo: "This task needs to be redone.",
      Discuss: "Your work looks good, discuss it with your tutor to complete.",
      "Ready for Feedback": "This task is ready for the tutor to assess to provide feedback.",
      Demonstrate: "Your work looks good, demonstrate it to your tutor to complete.",
      Fail: "You did not successfully demonstrate the required learning in this task.",
      "Time Exceeded": "You did not submit or complete the task before the appropriate deadline.",
      "Assess in Portfolio": "This task will not be signed off as complete by your tutor, and will be marked directly in your portfolio.",
      "Attention Required": "This task needs to be discussed with your tutor so that you can get back on track.",
      Rediscuss: "You attempted to discuss this task, but it was not adequate. Brush up your knowledge and return for another discussion to get the task signed off."
    }
    statuses.each do |name, desc|
      print "."
      TaskStatus.create(name: name, description: desc)
    end
    puts "!"
  end

  desc 'Initialise the app with an empty database and only minimal users (the superuser)'
  task init: [:environment] do
    generate_user_roles
    generate_task_statuses

    if User.count == 0
      puts "Creating admin user"
      username = :aadmin
      profile = {
        email: "#{username}@doubtfire.com",
        username: username,
        login_id: username,
        first_name: 'Admin',
        last_name: 'Admin',
        nickname: 'Admin',
        role_id: Role.admin_id
      }
      profile[:email]     ||=
        profile[:username] ||= username
      profile[:login_id]  ||= username

      if AuthenticationHelpers.db_auth?
        password = prompt_for_admin_password
        profile[:password] = password
        profile[:password_confirmation] = password
      end

      user = User.create!(profile)
    end
  end
end
