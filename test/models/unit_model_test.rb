require 'test_helper'
require 'grade_helper'

class UnitModelTest < ActiveSupport::TestCase
  include TestHelpers::JsonHelper
  include TestHelpers::TestFileHelper

  setup do
    @unit = FactoryBot.create :unit, code: 'COS10001', with_students: false, task_count: 0, tutorials: 0, outcome_count: 0, staff_count: 0, campus_count: 0, teaching_period: TeachingPeriod.find(3)
    @unit.add_tutorial_stream('Import-Tasks', 'import-tasks', ActivityType.first)
  end

  teardown do
    @unit.destroy
  end

  test 'import tasks worked' do
    @unit.import_tasks_from_csv File.open(Rails.root.join('test_files',"#{@unit.code}-Tasks.csv"))
    assert_equal 36, @unit.task_definitions.count, 'imported all task definitions'
  end

  test 'import task files' do
    @unit.import_tasks_from_csv File.open(Rails.root.join('test_files',"#{@unit.code}-Tasks.csv"))
    @unit.import_task_files_from_zip Rails.root.join('test_files',"#{@unit.code}-Tasks.zip")

    @unit.task_definitions.each do |td|
      assert File.exists?(td.task_sheet), "#{td.abbreviation} task sheet missing"
    end

    assert File.exists? @unit.task_definitions.first.task_resources
  end

  test 'rollover of task files' do
    @unit.import_tasks_from_csv File.open(Rails.root.join('test_files',"#{@unit.code}-Tasks.csv"))
    @unit.import_task_files_from_zip Rails.root.join('test_files',"#{@unit.code}-Tasks.zip")

    unit2 = @unit.rollover TeachingPeriod.find(2), nil, nil

    unit2.task_definitions.each do |td|
      assert File.exists?(td.task_sheet), 'task sheet is absent'
    end

    assert File.exists?(unit2.task_definitions.first.task_resources), 'task resource is absent'

    unit2.destroy
  end

  test 'rollover of group tasks' do
    unit = FactoryBot.create(:unit,
      code: 'SIT102',
      teaching_period: TeachingPeriod.find(3),
      group_sets: 1,
      student_count: 2,
      task_count: 1,
      groups: [ { gs: 0, students: 2} ],
      group_tasks: [ { idx: 0, gs: 0 }] )

    unit2 = unit.rollover TeachingPeriod.find(2), nil, nil

    assert_equal 1, unit2.group_sets.count
    assert_not_equal unit2.group_sets.first, unit.group_sets.first
    assert unit2.task_definitions.first.is_group_task?, unit2.task_definitions.inspect

    unit.destroy
    unit2.destroy
  end

  test 'rollover of task ilo links' do
    @unit.import_tasks_from_csv File.open(Rails.root.join('test_files',"#{@unit.code}-Tasks.csv"))
    @unit.import_outcomes_from_csv File.open(Rails.root.join('test_files',"#{@unit.code}-Outcomes.csv"))
    @unit.import_task_alignment_from_csv File.open(Rails.root.join('test_files',"#{@unit.code}-Alignment.csv")), nil

    unit2 = @unit.rollover TeachingPeriod.find(2), nil, nil

    assert @unit.task_outcome_alignments.count > 0
    assert_equal @unit.task_outcome_alignments.count, unit2.task_outcome_alignments.count

    @unit.task_outcome_alignments.each do |link|
      ilo = unit2.learning_outcomes.find_by(abbreviation: link.learning_outcome.abbreviation)
      task_def = unit2.task_definitions.find_by(abbreviation: link.task_definition.abbreviation)
      other = unit2.task_outcome_alignments.where(task_definition_id: task_def.id, learning_outcome_id: ilo.id).first

      assert other
      assert_equal link.rating, other.rating, "rating does not match for #{link.task_definition.abbreviation} - #{link.learning_outcome.abbreviation}"
    end
  end

  test 'rollover of tasks have same start week and day' do
    @unit.import_tasks_from_csv File.open(Rails.root.join('test_files',"#{@unit.code}-Tasks.csv"))

    unit2 = @unit.rollover TeachingPeriod.find(2), nil, nil

    assert_equal 3, @unit.teaching_period_id
    assert_equal 2, unit2.teaching_period_id

    @unit.task_definitions.each do |td|
      td2 = unit2.task_definitions.find_by_abbreviation(td.abbreviation)

      assert_equal td.start_day, td2.start_day, "#{td.abbreviation} not on same day"
      assert_equal td.start_week, td2.start_week, "#{td.abbreviation} not in same week"
    end
  end

  test 'rollover of tasks have same target week and day' do
    @unit.import_tasks_from_csv File.open(Rails.root.join('test_files',"#{@unit.code}-Tasks.csv"))

    unit2 = @unit.rollover TeachingPeriod.find(2), nil, nil

    @unit.task_definitions.each do |td|
      td2 = unit2.task_definitions.find_by_abbreviation(td.abbreviation)
      assert_equal td.target_day, td2.target_day, "#{td.abbreviation} not on same day"
      assert_equal td.target_week, td2.target_week, "#{td.abbreviation} not targetting same week"
    end
  end

  test 'rollover of tasks have same due week and day' do
    @unit.import_tasks_from_csv File.open(Rails.root.join('test_files',"#{@unit.code}-Tasks.csv"))

    unit2 = @unit.rollover TeachingPeriod.find(2), nil, nil

    @unit.task_definitions.each do |td|
      td2 = unit2.task_definitions.find_by_abbreviation(td.abbreviation)
      assert_equal td.due_day, td2.due_day, "#{td.abbreviation} not on same day"
      assert_equal td.due_week, td2.due_week, "#{td.abbreviation} not due same week"
    end
  end


  test 'ensure valid response from unit ilo data' do
    @unit.import_tasks_from_csv File.open(Rails.root.join('test_files',"#{@unit.code}-Tasks.csv"))
    @unit.import_outcomes_from_csv File.open(Rails.root.join('test_files',"#{@unit.code}-Outcomes.csv"))
    @unit.import_task_alignment_from_csv File.open(Rails.root.join('test_files',"#{@unit.code}-Alignment.csv")), nil

    DatabasePopulator.new.generate_tutorials_and_enrol_students_for_unit @unit, {
      tutors: [
        { user: :acain, num: 1 },
        { user: :aconvenor, num: 2 },
      ],
      students: [ ]
    }

    assert_equal 3, @unit.tutorials.count

    @unit.students.each do |student|
      @unit.task_definitions.each do |td|
        task = student.task_for_task_definition(td)
        tutor = student.tutor_for(td)

        case rand(1..100)
        when 1..20
          DatabasePopulator.assess_task(student, task, tutor, TaskStatus.complete, td.due_date + 1.week)
        when 21..40
          DatabasePopulator.assess_task(student, task, tutor, TaskStatus.ready_to_mark, td.due_date + 1.week)
        when 41..50
          DatabasePopulator.assess_task(student, task, tutor, TaskStatus.time_exceeded, td.due_date + 1.week)
        when 51..60
          DatabasePopulator.assess_task(student, task, tutor, TaskStatus.not_started, td.due_date + 1.week)
        when 61..70
          DatabasePopulator.assess_task(student, task, tutor, TaskStatus.working_on_it, td.due_date + 1.week)
        when 71..80
          DatabasePopulator.assess_task(student, task, tutor, TaskStatus.discuss, td.due_date + 1.week)
        else
          DatabasePopulator.assess_task(student, task, tutor, TaskStatus.fix_and_resubmit, td.due_date + 1.week)
        end

        break if rand(1..100) > 80
      end
    end

    details = @unit.ilo_progress_class_details

    assert details.key?('all'), 'contains all key'

    @unit.tutorials.each do |tute|
      assert details.key?(tute.id), 'contains tutorial keys'
    end
  end

  def test_student_query
    unit = FactoryBot.create(:unit, with_students: false)
    unit.employ_staff(User.first, Role.convenor)

    campus = FactoryBot.create(:campus)

    assert_empty unit.projects
    project = FactoryBot.create(:project, unit: unit, campus: campus)
    assert_equal 1, unit.projects.count


    # Make sure there are no enrolments for the project
    assert_empty project.tutorial_enrolments

    tutorial_stream_first = FactoryBot.create(:tutorial_stream, unit: unit)
    tutorial_stream_second = FactoryBot.create(:tutorial_stream, unit: unit)

    tutorial_first = FactoryBot.create(:tutorial, unit: unit, tutorial_stream: tutorial_stream_first, campus: campus)
    tutorial_second = FactoryBot.create(:tutorial, unit: unit, tutorial_stream: tutorial_stream_second, campus: campus)

    assert_not_nil tutorial_first.tutorial_stream
    assert_not_nil tutorial_second.tutorial_stream

    assert_equal tutorial_stream_first, tutorial_first.tutorial_stream
    assert_equal tutorial_stream_second, tutorial_second.tutorial_stream

    # Enrol project in tutorial first and second
    tutorial_enrolment_first = project.enrol_in(tutorial_first)
    tutorial_enrolment_second = project.enrol_in(tutorial_second)

    assert_equal tutorial_first, tutorial_enrolment_first.tutorial
    assert_equal project, tutorial_enrolment_first.project

    assert_equal tutorial_second, tutorial_enrolment_second.tutorial
    assert_equal project, tutorial_enrolment_second.project

    task_def_first = FactoryBot.create(:task_definition, unit: unit, tutorial_stream: tutorial_stream_first, target_grade: project.target_grade)
    task_def_second = FactoryBot.create(:task_definition, unit: unit, tutorial_stream: tutorial_stream_second, target_grade: project.target_grade)

    task_first = project.task_for_task_definition(task_def_first)
    task_second = project.task_for_task_definition(task_def_second)

    # Reload the unit
    unit.reload

    assert_equal 2, unit.student_tasks.count

    projects = unit.student_query(false)

    assert_equal unit.projects.count, projects.count
    assert_equal 1, projects.count

    # Check returned project
    assert_equal project.id, projects.first[:project_id]
    assert_equal project.enrolled, projects.first[:enrolled]

    # Ensure there are matching number of streams
    assert_equal unit.tutorial_streams.count, projects.first[:tutorial_enrolments].count

    # Now test with project without tutorial enrolments
    project2 = FactoryBot.create(:project, unit: unit, campus: campus)
    assert_equal 2, unit.projects.count

    project2.tutorial_enrolments.destroy

    projects = unit.student_query(false)

    assert_equal unit.projects.count, projects.count
    assert_equal 2, projects.count

    # Check returned project
    assert projects.select{|p| p[:project_id] == project2.id}.first.present?

    # Ensure there are matching number of streams
    assert_equal unit.tutorial_streams.count, projects.last[:tutorial_enrolments].count

    unit.tutorial_streams.each do |s|
      unit.projects.each do |p|
        proj_tute_enrolment = p.tutorial_enrolment_for_stream(s)
        data_tute_enrolment = projects.select{|ps| ps[:project_id] == p.id}.first[:tutorial_enrolments].select{|te| te[:stream_abbr] == s.abbreviation}.map{|te| te[:tutorial_id]}.first

        # if there is a enrolment for this project...
        if proj_tute_enrolment.present?
          # check that it matches the data returned
          assert_equal proj_tute_enrolment.tutorial_id, data_tute_enrolment
        else
          # check that the data returned nil for this stream
          assert_nil data_tute_enrolment
        end
      end
    end
  end

  def check_task_completion_csv unit, col_count = nil
    csv_str = unit.task_completion_csv

    CSV.parse(csv_str, headers: true, return_headers: false,
      header_converters: [->(body) { body.encode!('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '').downcase unless body.nil? }],
      converters: [->(body) { body.encode!('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '') unless body.nil? }]).each do |entry|

        assert_equal(col_count, entry.length, entry.inspect) unless col_count.nil?

        user = User.find_by(username: entry['username'])
        assert user.present?, entry.inspect

        project = unit.active_projects.find_by(user_id: user.id)

        # Test basic details
        assert_equal project.student.username, entry['username'], entry.inspect
        assert_equal project.student.student_id, entry['student_id'], entry.inspect
        assert_equal project.student.email, entry['email'], entry.inspect

        # Test task status
        unit.task_definitions.each do |td|
          task = project.task_for_task_definition(td)
          assert_equal task.task_status.name, entry[td.abbreviation.downcase], "#{td.abbreviation} --> #{entry.inspect}"

          assert_equal("#{task.quality_pts}", entry["#{td.abbreviation.downcase} stars"], "#{td.abbreviation} stars --> #{entry.inspect}") if td.has_stars? && task.quality_pts != -1
          assert_equal(GradeHelper.short_grade_for(task.grade), entry["#{td.abbreviation.downcase} grade"], "#{td.abbreviation} --> #{entry.inspect}") if td.is_graded?
          assert_equal(task.contribution_pts, (entry["#{td.abbreviation.downcase} contribution"].nil? ? 3 : Integer(entry["#{td.abbreviation.downcase} contribution"])), "#{td.abbreviation} contrib --> #{entry.inspect}") if td.is_group_task?
        end

        # Test tutorial streams
        unit.tutorial_streams.each do |ts|
          assert_equal (project.tutorial_for_stream(ts).present? ? project.tutorial_for_stream(ts).abbreviation : nil), entry[ts.abbreviation.downcase], {entry: entry.inspect, stream: ts.abbreviation, proj_tut: project.tutorial_for_stream(ts)}
        end
    end
  end

  def test_task_completion_csv
    unit = FactoryBot.create :unit, campus_count: 2, tutorials:2, stream_count:2, task_count:3, student_count:8, unenrolled_student_count: 1, part_enrolled_student_count: 2, set_one_of_each_task: true

    unit.task_definitions.each do |td|
      unit.projects.each do |student|
        task = student.task_for_task_definition(td)
        tutor = student.tutor_for(td)

        DatabasePopulator.assess_task(student, task, tutor, TaskStatus.all.sample, td.start_date + 1.week)
      end
    end

    # 17 = 8 general + 2 streams + 3 task defs + 1 group details + 1 stars + 1 grade + 1 contrib
    check_task_completion_csv unit, 17
  end

  def test_task_completion_csv_no_task_data
    unit = FactoryBot.create :unit, campus_count: 2, tutorials:2, stream_count:2, task_count:3, student_count:8, unenrolled_student_count: 1, part_enrolled_student_count: 2, set_one_of_each_task: true

    check_task_completion_csv unit
  end

  def test_task_completion_csv_all_td_in_one_stream
    unit = FactoryBot.create :unit, campus_count: 2, tutorials:1, stream_count:1, task_count:1, student_count:3, unenrolled_student_count: 0, part_enrolled_student_count: 0

    unit.tutorial_streams << FactoryBot.create(:tutorial_stream, unit: unit)
    tutorial = FactoryBot.create(:tutorial, unit: unit, tutorial_stream: unit.tutorial_streams.last, campus: Campus.last )

    unit.projects.where(campus: tutorial.campus).first.enrol_in(tutorial)

    assert unit.task_definitions.first.tutorial_stream.present?
    assert_equal 2, unit.tutorial_streams.count

    check_task_completion_csv unit
  end

  def test_export_users
    unit = FactoryBot.create :unit, campus_count: 2, tutorials:2, stream_count:0, task_count:3, student_count:8, unenrolled_student_count: 0, part_enrolled_student_count: 0, set_one_of_each_task: true

    csv_str = unit.export_users_to_csv

    rows = 0
    CSV.parse(csv_str, headers: true, return_headers: false,
      header_converters: [->(body) { body.encode!('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '').downcase unless body.nil? }],
      converters: [->(body) { body.encode!('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '') unless body.nil? }]).each do |entry|
        assert_equal 9, entry.count, entry
        user = User.find_by(username: entry['username'])
        assert user.present?, "Unable to find user from #{entry}"

        project = unit.projects.find_by(user_id: user.id)
        assert project.present?, entry

        assert_json_matches_model(user, entry, %w( username student_id first_name last_name email))

        campus = Campus.find_by_abbr_or_name entry['campus']
        assert campus.present?, entry
        assert_equal project.campus, campus, entry

        assert_equal user.nickname, entry['preferred_name'], entry

        tutorial = unit.tutorials.find_by(abbreviation: entry['tutorial'])
        assert tutorial.present?, entry['tutorial']
        assert_equal project.tutorial_enrolments.first.tutorial, tutorial, entry

        rows += 1
    end

    assert_equal unit.active_projects.count, rows, "Expected number or rows in csv - #{csv_str}"
  end

  def test_import_users
    unit = FactoryBot.create(:unit, code: 'SIT101', stream_count: 0, with_students: false)
    t1 = unit.add_tutorial(
      'Monday',
      '8:00am',
      'TBA',
      unit.main_convenor_user,
      Campus.find_by(abbreviation: 'B'),
      10,
      'LA1-01'
    )
    t2 = unit.add_tutorial(
      'Monday',
      '8:00am',
      'TBA',
      unit.main_convenor_user,
      Campus.find_by(abbreviation: 'C'),
      10,
      'LA1-03'
    )
    assert_equal 0, unit.projects.count

    assert_not_nil t1.campus
    assert_not_nil t2.campus

    result = unit.import_users_from_csv test_file_path('SIT101-Enrol-Students.csv')
    unit.reload
    assert_equal 1, result[:errors].count, result.inspect
    assert_equal 1, result[:ignored].count, result.inspect
    assert_equal 10, unit.projects.count, result.inspect

    assert_equal Campus.find_by(abbreviation: 'C'), User.find_by(username: 'import_8').projects.find_by(unit_id: unit.id).campus

    assert_equal 3, t1.projects.count, result.inspect
    assert_equal 3, t2.projects.count
    
    unit.destroy!
  end

  def test_import_users_streamed
    unit = FactoryBot.create(:unit, code: 'SIT101', stream_count: 0, with_students: false)
    s1 = unit.add_tutorial_stream('Stream 1', 'Prc01', ActivityType.first)
    s2 = unit.add_tutorial_stream('Stream 2', 'Stu01', ActivityType.first)

    t1 = unit.add_tutorial(
      'Monday',
      '8:00am',
      'TBA',
      unit.main_convenor_user,
      Campus.find_by(abbreviation: 'B'),
      10,
      'LA1-01',
      s1
    )
    t2 = unit.add_tutorial(
      'Monday',
      '8:00am',
      'TBA',
      unit.main_convenor_user,
      Campus.find_by(abbreviation: 'C'),
      10,
      'LA1-03',
      s1
    )
    t3 = unit.add_tutorial(
      'Monday',
      '8:00am',
      'TBA',
      unit.main_convenor_user,
      nil,
      10,
      'LA1-02',
      s2
    )

    assert_equal 0, unit.projects.count

    result = unit.import_users_from_csv test_file_path('SIT101-Enrol-Students-Stream.csv')
    unit.reload
    assert_equal 0, result[:errors].count, result.inspect
    assert_equal 0, result[:ignored].count, result.inspect
    assert_equal 8, unit.projects.count, result.inspect

    assert_equal 4, t1.projects.count
    assert_equal 4, t2.projects.count
    assert_equal 8, t3.projects.count
    
    unit.destroy!
  end

  def test_change_main_convenor_success
    unit = FactoryBot.create :unit, campus_count: 1, tutorials:0, stream_count:0, task_count:0, with_students:false

    admin_user = FactoryBot.create :user, :admin
    convenor_user = FactoryBot.create :user, :convenor

    admin_user_role = unit.employ_staff admin_user, Role.convenor
    convenor_user_role = unit.employ_staff convenor_user, Role.convenor

    unit.main_convenor_id = admin_user_role.id
    assert unit.valid?, 'It should be ok to change to the admin user'

    unit.main_convenor_id = convenor_user_role.id
    assert unit.valid?, 'It should be ok to change to the convenor user'
  end

  def test_change_main_convenor_does_not_allow_roles_from_other_units
    unit = FactoryBot.create :unit, campus_count: 1, tutorials:0, stream_count:0, task_count:0, with_students:false
    other_unit = FactoryBot.create :unit, campus_count: 1, tutorials:0, stream_count:0, task_count:0, with_students:false

    admin_user = FactoryBot.create :user, :admin
    convenor_user = FactoryBot.create :user, :convenor

    admin_user_role = other_unit.employ_staff admin_user, Role.convenor
    convenor_user_role = other_unit.employ_staff convenor_user, Role.convenor

    assert unit.valid?, 'Should be valid before changes... check factory girl!'

    unit.main_convenor_id = admin_user_role.id
    refute unit.valid?, 'It should not be ok to change to the admin user from other unit'

    unit.main_convenor_id = convenor_user_role.id
    refute unit.valid?, 'It should not be ok to change to the convenor user from other unit'
  end

  def test_change_main_convenor_does_not_allow_non_convneor_roles
    unit = FactoryBot.create :unit, campus_count: 1, tutorials:0, stream_count:0, task_count:0, with_students:false

    admin_user = FactoryBot.create :user, :admin
    convenor_user = FactoryBot.create :user, :convenor

    admin_user_role = unit.employ_staff admin_user, Role.tutor
    convenor_user_role = unit.employ_staff convenor_user, Role.tutor

    unit.main_convenor_id = admin_user_role.id
    refute unit.valid?, 'It should not be ok to change to the admin user with no convenor access to unit'

    unit.main_convenor_id = convenor_user_role.id
    refute unit.valid?, 'It should not be ok to change to the convenor user with no convenor access to unit'
  end

  def test_change_main_convenor_does_not_allow_students_to_be_epmployed
    unit = FactoryBot.create :unit, campus_count: 1, tutorials:0, stream_count:0, task_count:0, with_students:false

    convenor_user = FactoryBot.create :user, :convenor
    student_user = FactoryBot.create :user, :student

    student_user_role = unit.employ_staff student_user, Role.tutor
    assert student_user_role.nil?

    #force this test... work around validations
    student_user_role = unit.employ_staff convenor_user, Role.convenor
    student_user_role.user = student_user

    refute student_user_role.valid?, 'You should not be able to change a unit role to have a student!'

    unit.main_convenor = student_user_role
    refute unit.valid?, 'Even if the above validation fails, the student user role should not be able to admin unit'
  end

  def test_portfolio_zip
    unit = FactoryBot.create :unit, campus_count: 2, tutorials:2, stream_count:2, task_count:1, student_count:1, unenrolled_student_count: 0, part_enrolled_student_count: 1

    paths = []

    unit.active_projects.each do |p|
      DatabasePopulator.generate_portfolio(p)
      assert p.has_portfolio
      assert File.exists?(p.portfolio_path)
      paths << p.portfolio_path
    end

    filename = unit.get_portfolio_zip(unit.main_convenor_user)
    assert File.exists? filename
    Zip::File.open(filename) do |zip_file|
      assert_equal unit.active_projects.count, zip_file.count
    end
    FileUtils.rm filename

    unit.destroy!

    paths.each do |path|
      refute File.exists?(path)
    end
  end

  def test_send_summary_email
    unit = FactoryBot.create :unit

    summary_stats = {}

    summary_stats[:week_end] = Date.today
    summary_stats[:week_start] = summary_stats[:week_end] - 7.days
    summary_stats[:weeks_comments] = TaskComment.where("created_at >= :start AND created_at < :end", start: summary_stats[:week_start], end: summary_stats[:week_end]).count
    summary_stats[:weeks_engagements] = TaskEngagement.where("engagement_time >= :start AND engagement_time < :end", start: summary_stats[:week_start], end: summary_stats[:week_end]).count

    unit.send_weekly_status_emails(summary_stats)
  end

end
