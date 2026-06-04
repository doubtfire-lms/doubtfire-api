require 'active_support/testing/time_helpers'

# lib/tasks/simulate_marking_sessions.rake
namespace :db do
  desc 'Simulate marking sessions'
  task simulate_marking_sessions: [:skip_prod, :environment] do
    include ActiveSupport::Testing::TimeHelpers

    unit = Unit.first
    user = unit.staff.first.user
    project = unit.projects.first
    task = project.tasks.first
    unit_role = unit.employ_staff(user, Role.convenor)

    MarkingSession.delete_all

    activity_type = ActivityType.find_by(name: "Feedback")
    activity_type = ActivityType.create(name: "Feedback", abbreviation: "Feedback") if activity_type.nil?

    tutorial_stream = TutorialStream.find_by(abbreviation: "feedback1")
    if tutorial_stream.nil?
      tutorial_stream = TutorialStream.create!({
                                                 name: "feedback1",
                                                 abbreviation: "feedback1",
                                                 unit: unit,
                                                 activity_type_id: activity_type.id,
                                                 activity_type: activity_type
                                               })
    end

    tutorial_stream.tutorials.delete_all
    tutorial1 = Tutorial.create!({
                                   unit: unit,
                                   meeting_day: "Wednesday",
                                   meeting_time: "8:00",
                                   meeting_location: "-",
                                   code: "Tutorial1",
                                   unit_role: unit_role,
                                   abbreviation: "Tutorial1",
                                   tutorial_stream: tutorial_stream
                                 })

    tutorial2 = Tutorial.create!({
                                   unit: unit,
                                   meeting_day: "Wednesday",
                                   meeting_time: "11:00",
                                   meeting_location: "-",
                                   code: "Tutorial2",
                                   unit_role: unit_role,
                                   abbreviation: "Tutorial2",
                                   tutorial_stream: tutorial_stream
                                 })

    tutorial3 = Tutorial.create!({
                                   unit: unit,
                                   meeting_day: "Wednesday",
                                   meeting_time: "13:00",
                                   meeting_location: "-",
                                   code: "Tutorial3",
                                   unit_role: unit_role,
                                   abbreviation: "Tutorial3",
                                   tutorial_stream: tutorial_stream
                                 })

    tutorial4 = Tutorial.create!({
                                   unit: unit,
                                   meeting_day: "Thursday",
                                   meeting_time: "12:00",
                                   meeting_location: "-",
                                   code: "Tutorial4",
                                   unit_role: unit_role,
                                   abbreviation: "Tutorial4",
                                   tutorial_stream: tutorial_stream
                                 })

    # Find the most recent Wednesday
    today = Time.zone.today
    wednesday_offset = (today.wday - 3) % 7
    wednesday = today - wednesday_offset.days

    # start_time = wednesday.to_time.change(hour: 10, min: 0) # 10:00am
    start_time = wednesday.in_time_zone.change(hour: 5, min: 4) # 11:05am
    end_time   = wednesday.in_time_zone.change(hour: 18, min: 0) # 3:00pm

    current_time = start_time

    while current_time <= end_time
      travel_to current_time do
        SessionTracker.record_assessment_activity(
          action: 'get-submission-details',
          user: user,
          project: project,
          ip_address: '127.0.0.1',
          task: task
        )
      end

      current_time += 5.minutes
    end

    thursday = wednesday + 1.day
    # thursday_offset = (today.wday - 4) % 7
    # thursday = today - thursday_offset.days

    start_time = thursday.in_time_zone.change(hour: 12, min: 4) # 12:05pm
    end_time   = thursday.in_time_zone.change(hour: 15, min: 0) # 3:00pm

    current_time = start_time

    while current_time <= end_time
      travel_to current_time do
        SessionTracker.record_assessment_activity(
          action: 'get-submission-details',
          user: user,
          project: project,
          ip_address: '127.0.0.1',
          task: task
        )
      end

      current_time += 5.minutes
    end

    byebug

    start_time = thursday.in_time_zone.change(hour: 17, min: 0) # 12:05pm
    end_time = thursday.in_time_zone.change(hour: 18, min: 0) # 3:00pm

    current_time = start_time

    while current_time <= end_time
      travel_to current_time do
        SessionTracker.record_assessment_activity(
          action: 'get-submission-details',
          user: user,
          project: project,
          ip_address: '127.0.0.1',
          task: task
        )
      end

      current_time += 5.minutes
    end
  end
end

def aggregate_task_complete_stats
  result = {}

  unit = Unit.first

  unit.task_definitions.each do |td|
    result[td.abbreviation] = {}
  end

  unit.active_projects.each do |project|
    campus_name = project.campus.name
    result[campus_name] ||= {}

    unit.task_definitions.each do |td|
      result[campus_name][td.abbreviation] ||= {}

      unless project.has_task_for_task_definition?(td)
        # Count not started
        result[campus_name][td.abbreviation]['1'] ||= 0
        result[campus_name][td.abbreviation]['1'] += 1
        next
      end

      task = project.task_for_task_definition(td)
      next unless task

      status = task.task_status.id.to_s
      result[campus_name][td.abbreviation][status] ||= 0
      result[campus_name][td.abbreviation][status] += 1
    end
  end

  file_server = Doubtfire::Application.config.student_work_dir
  analytics_dir = File.join(file_server, "analytics")
  FileUtils.mkdir_p(analytics_dir)

  File.write("#{analytics_dir}/#{unit.code}-#{unit.id}-stats.json", result.to_json)
end
