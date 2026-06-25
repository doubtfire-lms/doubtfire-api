require 'json'

class TaskDefinition < ApplicationRecord
  include ApplicationHelper
  include FileHelper
  include MimeCheckHelpers
  include CsvHelper

  def self.permissions
    convenor_role_permissions = [
      :create_feedback_chips,
      :get_feedback_chips,
      :update,
      :upload_csv,
      :get_los,
      :create_task_prerequisite,
      :get_discussion_prompt,
      :create_discussion_prompt,
      :manage_overseer_steps
    ]

    admin_role_permissions = [
      :create_feedback_chips,
      :get_feedback_chips,
      :update,
      :upload_csv,
      :get_los,
      :create_task_prerequisite,
      :get_discussion_prompt,
      :create_discussion_prompt,
      :manage_overseer_steps
    ]

    tutor_role_permissions = [
      :get_feedback_chips,
      :get_los,
      :get_discussion_prompt,
      :create_discussion_prompt
    ]

    auditor_role_permissions = [
      :get_feedback_chips
    ]

    nil_role_permissions = []

    {
      convenor: convenor_role_permissions,
      admin: admin_role_permissions,
      tutor: tutor_role_permissions,
      auditor: auditor_role_permissions,
      nil: nil_role_permissions
    }
  end

  delegate :role_for, to: :unit

  before_destroy :delete_associated_files

  after_update :move_files_on_abbreviation_change, if: :saved_change_to_abbreviation?
  after_update :remove_old_group_submissions, if: :has_removed_group?
  after_update :check_and_update_tii_status, if: :saved_change_to_upload_requirements?
  after_update :update_tii_group, if: :saved_change_to_due_date?
  after_update :update_overdue_tasks_aip, if: :saved_change_to_assess_in_portfolio_only?
  after_update :reset_overdue_tasks, if: :saved_change_to_due_date?

  # Model associations
  belongs_to :unit, optional: false # Foreign key
  belongs_to :group_set, optional: true
  belongs_to :tutorial_stream, optional: true
  belongs_to :overseer_image, optional: true

  has_many :tasks, dependent:  :destroy # Destroying a task definition will also nuke any instances
  has_many :group_submissions, dependent: :destroy # Destroying a task definition will also nuke any group submissions
  has_many :learning_outcomes, as: :context, dependent: :destroy
  has_many :overseer_steps, -> { order(:sort_order) }, inverse_of: :task_definition, dependent: :destroy

  has_many :tii_group_attachments, dependent: :destroy # destroy uploaded files to tii - after the tasks
  has_many :tii_actions, as: :entity, dependent: :destroy

  has_many :task_prerequisites, dependent: :destroy
  has_many :prerequisites, through: :task_prerequisites, source: :prerequisite

  has_many :grade_due_dates,
           class_name: "TaskDefinitionGradeDueDate",
           dependent: :destroy

  has_many :discussion_prompts, dependent: :destroy

  serialize :upload_requirements, coder: JSON

  # Model validations/constraints
  validates :name, uniqueness: { scope:  :unit_id } # task definition names within a unit must be unique
  validates :abbreviation, uniqueness: { scope: :unit_id } # task definition names within a unit must be unique

  validates :target_grade, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :target_grade_enabled_for_unit
  validates :max_quality_pts, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100, message: 'must be between 0 and 100' }

  validate :upload_requirements, :check_upload_requirements_format
  validate :submission_history_required_for_overseer

  validates :description, length: { maximum: 4095, allow_blank: true }

  validate :ensure_no_submissions, if: :will_save_change_to_group_set_id?
  validate :unit_must_be_same
  validate :tutorial_stream_present?

  validates :weighting, presence: true

  validate :check_existing_prerequisites

  validate :cant_disable_aip_only_if_aip_tasks_exist

  include TaskDefinitionTiiModule
  include TaskDefinitionSimilarityModule

  def grade_due_date_overrides
    grade_due_dates.map do |override|
      {
        target_grade: override.target_grade,
        target_due_date: override.target_due_date,
        start_date: override.start_date
      }
    end
  end

  def grade_target_date(target_grade)
    grade_due_dates.find { |g| g.target_grade == target_grade.to_i }&.target_due_date
  end

  def grade_start_date(target_grade)
    grade_due_dates.find { |g| g.target_grade == target_grade.to_i }&.start_date
  end

  def unit_must_be_same
    if unit.present? and tutorial_stream.present? and not unit.eql? tutorial_stream.unit
      errors.add(:unit, "should be same as the unit in the associated tutorial stream")
    end
  end

  def tutorial_stream_present?
    if tutorial_stream.nil? and unit.tutorial_streams.exists?
      errors.add(:tutorial_stream, "must be one of the tutorial streams in the unit")
    end
  end

  def cant_disable_aip_only_if_aip_tasks_exist
    return unless will_save_change_to_assess_in_portfolio_only?
    return if assess_in_portfolio_only? # only care about disabling

    if tasks.where(task_status_id: TaskStatus.assess_in_portfolio.id).exists?
      errors.add(:assess_in_portfolio_only, "cannot be disabled while tasks are in the Assess in Portfolio state")
    end
  end

  def check_existing_prerequisites
    prereqs = TaskPrerequisite.where(task_definition_id: id)
    prereqs.each do |dp|
      if target_grade < dp.prerequisite.target_grade
        errors.add(:target_grade, "cannot be lower than prerequisite #{dp.prerequisite.abbreviation}'s target grade")
      end
    end

    dependents = TaskPrerequisite.where(prerequisite_id: id)
    dependents.each do |pr|
      if target_grade > pr.task_definition.target_grade
        errors.add(:target_grade, "cannot exceed the target grade #{pr.task_definition.abbreviation} because this is a prerequisite")
      end
    end
  end

  # In the rollover process, copy this definition into another unit
  # Copy this task into the other unit
  def copy_to(other_unit)
    new_td = self.dup

    # change the unit...
    new_td.unit_id = other_unit.id          # for database
    new_td.unit = other_unit                # for other operations
    other_unit.task_definitions << new_td   # so we can see it in unit elsewhere

    # Change tutorial stream
    new_td.tutorial_stream = other_unit.tutorial_streams.find_by(abbreviation: tutorial_stream.abbreviation) unless tutorial_stream.nil?

    # change group set
    if is_group_task?
      # Find based upon the group set in the new unit
      new_td.group_set = other_unit.group_sets.find_by(name: self.group_set.name)
    end

    # Adjust dates
    new_td.start_week_and_day = start_week, start_day
    new_td.target_week_and_day = target_week, target_day

    if self['due_date'].present?
      new_td.due_week_and_day = due_week, due_day
    end

    # Ensure we have the dir for the destination task sheet
    FileHelper.task_file_dir_for_unit(other_unit, create = true)

    if has_task_sheet?
      FileUtils.cp(task_sheet, new_td.task_sheet())
    end

    if has_task_resources?
      # Copy the task resources, and trigger tii integration if needed
      new_td.add_task_resources(task_resources, copy: true)
    end

    if has_scorm_data?
      new_td.add_scorm_data(task_scorm_data, copy: true)
    end

    new_td.save!
    overseer_steps.find_each do |step|
      new_td.overseer_steps.create!(
        step.attributes.except('id', 'task_definition_id', 'created_at', 'updated_at')
      )
    end

    new_td
  end

  def has_removed_group?
    saved_change_to_group_set_id? && group_set_id.nil?
  end

  def ensure_no_submissions
    if tasks.where("submission_date IS NOT NULL").count() > 0
      errors.add(:group_set, "Unable to change group status of task as submissions exist")
    end
  end

  def remove_old_group_submissions
    if group_set_id.nil? && group_submissions.count > 0
      group_submissions.destroy_all
    end
  end

  def detailed_name
    "#{abbreviation} #{name}"
  end

  def update_overdue_tasks_aip
    return unless saved_change_to_assess_in_portfolio_only? && assess_in_portfolio_only?

    overdue_statuses = [TaskStatus.time_exceeded.id]

    tasks.where(task_status_id: overdue_statuses).find_each do |task|
      task.add_status_comment(unit.main_convenor.user, TaskStatus.assess_in_portfolio)
      task.update(task_status_id: TaskStatus.assess_in_portfolio.id)
    end
  end

  def reset_overdue_tasks
    original_due_date = saved_change_to_due_date&.first
    return unless original_due_date
    return if assess_in_portfolio_only

    late_submissions = tasks
                       .where('submission_date > ?', original_due_date)
                       .where(task_status: [TaskStatus.time_exceeded, TaskStatus.assess_in_portfolio])

    late_submissions.each do |task|
      task.add_status_comment(unit.main_convenor.user, TaskStatus.ready_for_feedback)
      task.update(task_status_id: TaskStatus.ready_for_feedback.id)
    end
  end

  def move_files_on_abbreviation_change
    old_abbr = saved_change_to_abbreviation[0] # 0 is original abbreviation
    if File.exist? task_sheet_with_abbreviation(old_abbr, false)
      FileUtils.mv(task_sheet_with_abbreviation(old_abbr), task_sheet())
    end

    if File.exist? task_resources_with_abbreviation(old_abbr, false)
      FileUtils.mv(task_resources_with_abbreviation(old_abbr), task_resources())
    end

    if File.exist? task_assessment_resources_with_abbreviation(old_abbr, false)
      FileUtils.mv(task_assessment_resources_with_abbreviation(old_abbr), task_assessment_resources())
    end

    if File.exist? task_scorm_data_with_abbreviation(old_abbr, false)
      FileUtils.mv(task_scorm_data_with_abbreviation(old_abbr), task_scorm_data())
    end

    tasks.find_each do |task|
      task.move_files_on_abbreviation_change(old_abbr)
    end
  end

  def docker_image_name_tag
    return nil if overseer_image.nil?

    overseer_image.tag
  end

  def glob_for_upload_requirement(idx)
    "#{idx.to_s.rjust(3, '0')}-#{upload_requirements[idx]['type']}.*"
  end

  # Validate the format of the upload requirements
  def check_upload_requirements_format
    json_data = self.upload_requirements
    return if json_data.nil?

    # ensure we have a structure that is : [ { "key": "...", "name": "...", "type": "...", "tii_check": "...", "tii_pct": "..."}, { ... } ]
    unless json_data.class == Array
      errors.add(:upload_requirements, 'is not in a valid format! Should be [ { "key": "...", "name": "...", "type": "...", "tii_check": "...", "tii_pct": "..."}, { ... } ]. Did not contain array.')
      return
    end

    # Checking each upload requirement - i used to index files and for user errors
    i = 0
    for req in json_data do
      # Each requirement is a json object
      unless req.class == Hash
        errors.add(:upload_requirements, "is not in a valid format! Should be [ { \"key\": \"...\", \"name\": \"...\", \"type\": \"...\", \"tii_check\": \"...\", \"tii_pct\": \"...\"}, { ... } ]. Array did not contain hashes for item #{i + 1}..")
        return
      end

      # Check we have the keys we need
      if (!req.key? 'key') || (!req.key? 'name') || (!req.key? 'type')
        errors.add(:upload_requirements, "is not in a valid format! Must contain [ { \"key\": \"...\", \"name\": \"...\", \"type\": \"...\"}, { ... } ]. Missing a key for item #{i + 1}.")
        return
      end

      req['type'] = 'zip' if req['type'] == 'archive'

      # Check keys only contain supported upload requirement settings
      unless req.keys.excluding('key', 'type', 'name', 'tii_check', 'tii_pct', 'submission_history').empty?
        errors.add(:upload_requirements, "has additional values for item #{i + 1} --> #{req.keys.join(' ')}.")
      end

      # Check the name matches a valid filename format
      unless req['name'].match?(/^[a-zA-Z0-9_\- .]+$/)
        errors.add(:upload_requirements, "the name for item #{i + 1} does not seem to be a valid filename --> #{req['name']}.")
      end

      # Check the type is either document, image, code, or zip
      unless %w(document image code zip).include? req['type']
        errors.add(:upload_requirements, "the type for item #{i + 1} is not valid --> #{req['type']}.")
      end

      # Check that tii check is a boolean
      unless req['tii_check'].blank? || [true, false].include?(req['tii_check'])
        errors.add(:upload_requirements, "the tii_check for item #{i + 1} is not a boolean --> #{req['tii_check']}.")
      end

      # Check that tii_pct is a non-negative number
      unless req['tii_pct'].blank? || (req['tii_pct'].is_a?(Numeric) && req['tii_pct'] >= 0)
        errors.add(:upload_requirements, "the tii_pct for item #{i + 1} is not a non-negative number --> #{req['tii_pct']}.")
      end

      unless req['submission_history'].blank? || [true, false].include?(req['submission_history'])
        errors.add(:upload_requirements, "the submission_history for item #{i + 1} is not a boolean --> #{req['submission_history']}.")
      end

      i += 1
    end
  end

  def submission_history_required_for_overseer
    return unless assessment_enabled?
    return if upload_requirements&.any? { |requirement| requirement['submission_history'] == true }

    errors.add(:upload_requirements, 'must include at least one file in submission history when Overseer is enabled')
  end

  def number_of_uploaded_files
    upload_requirements.length
  end

  def number_of_documents
    upload_requirements.map{|req| req['type'] == 'document' ? 1 : 0}.inject(:+) || 0
  end

  # Returns true if the uploaded file is a document
  def is_document?(idx)
    return false unless idx >= 0 && idx < upload_requirements.length
    upload_requirements[idx]['type'] == 'document'
  end

  # Return the type for the upload at the given index
  # @param idx the index of the upload requirement
  def type_for_upload(idx)
    return nil unless idx >= 0 && idx < upload_requirements.length
    upload_requirements[idx]['type']
  end

  def self.to_csv(task_definitions)
    CSV.generate() do |csv|
      csv << csv_columns
      task_definitions.each do |task_definition|
        csv << task_definition.to_csv_row
      end
    end
  end

  # Export the learning outcomes for this task definition to a CSV file
  # @param _include_tlos [Boolean] ignored as at the task definition level already
  def export_learning_outcome_to_csv(*)
    CSV.generate do |row|
      row << LearningOutcome.csv_header
      learning_outcomes.each do |outcome|
        outcome.add_csv_row row
      end
    end
  end

  def export_feedback_chips_to_csv(*)
    CSV.generate do |row|
      row << Feedback::FeedbackChip.csv_header
      learning_outcomes.each do |outcome|
        outcome.feedback_chips.each do |chip|
          chip.add_csv_row row
        end
      end
    end
  end

  def export_title
    abbreviation
  end

  def import_outcomes_from_csv(file)
    result = {
      success: [],
      errors: [],
      ignored: []
    }

    data = read_file_to_str(file)

    CSV.parse(data,
              headers: true,
              header_converters: [->(i) { i.nil? ? '' : i }, :downcase, ->(hdr) { hdr&.strip }],
              converters: [->(body) { body&.encode('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '') }]).each do |row|
      # Make sure we're not looking at the header or an empty line
      next if row[0] =~ /abbreviation/

      begin
        LearningOutcome.create_from_csv(unit, self, row, result)
      rescue StandardError => e
        result[:errors] << { row: row, message: e.message.to_s }
      end
    end

    result
  end

  def start_week
    unit.week_number(start_date)
  end

  def start_day
    Date::ABBR_DAYNAMES[start_date.wday]
  end

  def start_week_and_day= value
    week, day = value
    self.start_date = unit.date_for_week_and_day(week, day)
  end

  def target_week
    unit.week_number(target_date)
  end

  def target_day
    Date::ABBR_DAYNAMES[target_date.wday]
  end

  def target_week_and_day= value
    week, day = value
    self.target_date = unit.date_for_week_and_day(week, day)
  end

  # Override due date to return either the final date of the unit, or the set due date
  def due_date
    return self['due_date'] if self['due_date'].present?

    return unit.end_date # TODO: use nil as default to improve performance
  end

  def due_week
    if due_date.present?
      unit.week_number(due_date)
    else
      ''
    end
  end

  def due_week_and_day= value
    week, day = value
    self.due_date = unit.date_for_week_and_day(week, day)
  end

  def due_day
    if due_date
      Date::ABBR_DAYNAMES[due_date.wday]
    else
      ''
    end
  end

  # Update all task dates by date_diff
  def propogate_date_changes date_diff
    self.start_date += date_diff
    self.target_date += date_diff
    self.due_date += date_diff unless self.due_date.nil?
    self.save!
  end

  def to_csv_row
    TaskDefinition.csv_columns
                  .reject { |col| [:start_week, :start_day, :target_week, :target_day, :due_week, :due_day, :upload_requirements, :group_set, :tutorial_stream, :assess_in_portfolio_only, :task_prerequisites, :discussion_prompts, :overseer_steps].include? col}
                  .map { |column| attributes[column.to_s] } +
      [
        group_set.nil? ? "" : group_set.name,
        upload_requirements.to_json,
        start_week,
        start_day,
        target_week,
        target_day,
        due_week,
        due_day,
        tutorial_stream.present? ? tutorial_stream.abbreviation : nil,
        assess_in_portfolio_only,
        task_prerequisites.map do |tp|
          prereq = TaskDefinition.find(tp.prerequisite_id)
          {
            abbreviation: prereq.abbreviation,
            task_status_id: tp.task_status_id
          }
        end.to_json,
        discussion_prompts.map do |prompt|
        {
          content: prompt.content,
          priority: prompt.priority
        }
        end.to_json,
        overseer_steps.map do |step|
          {
            name: step.name,
            description: step.description,
            display_name: step.display_name,
            display_description: step.display_description,
            run_command: step.run_command,
            timeout: step.timeout,
            sort_order: step.sort_order,
            step_type: step.step_type,
            partial_output_diff: step.partial_output_diff,
            stdin_input_file: step.stdin_input_file,
            expected_output_file: step.expected_output_file,
            feedback_message: step.feedback_message,
            status_on_success: TaskStatus.find_by(id: step.status_on_success_id)&.status_key,
            status_on_failure: TaskStatus.find_by(id: step.status_on_failure_id)&.status_key,
            halt_on_success: step.halt_on_success,
            halt_on_failure: step.halt_on_failure,
            show_expected_output: step.show_expected_output,
            show_stdin: step.show_stdin,
            show_stdout: step.show_stdout,
            enabled: step.enabled
          }
        end.to_json
      ]
    # [target_date.strftime('%d-%m-%Y')] +
    # [ self['due_date'].nil? ? '' : due_date.strftime('%d-%m-%Y')]
  end

  def self.csv_columns
    [:name, :abbreviation, :description, :weighting, :target_grade, :restrict_status_updates, :max_quality_pts,
     :is_graded, :plagiarism_warn_pct, :scorm_enabled, :scorm_allow_review, :scorm_bypass_test, :scorm_time_delay_enabled,
     :scorm_attempt_limit, :group_set, :upload_requirements, :start_week, :start_day, :target_week, :target_day,
     :due_week, :due_day, :tutorial_stream, :assess_in_portfolio_only, :task_prerequisites, :discussion_prompts, :overseer_steps]
  end

  def self.required_csv_columns
    csv_columns - [:overseer_steps]
  end

  def self.task_def_for_csv_row(unit, row)
    return [nil, false, 'Abbreviation and name cannot be empty.'] if row[:abbreviation].nil? || row[:name].nil? || row[:abbreviation].empty? || row[:name].empty?

    new_task = false
    abbreviation = row[:abbreviation].strip
    name = row[:name].strip
    tutorial_stream = unit.tutorial_streams.find_by('abbreviation = :name OR name = :name', name: "#{row[:tutorial_stream]}".strip)
    target_date = unit.date_for_week_and_day row[:target_week].to_i, "#{row[:target_day]}".strip
    return [nil, false, "Unable to determine target date for #{abbreviation} -- need week number, and day short text eg. 'Wed'"] if target_date.nil?

    start_date = unit.date_for_week_and_day row[:start_week].to_i, "#{row[:start_day]}".strip
    return [nil, false, "Unable to determine start date for #{abbreviation} -- need week number, and day short text eg. 'Wed'"] if start_date.nil?

    due_date = unit.date_for_week_and_day row[:due_week].to_i, "#{row[:due_day]}".strip

    result = TaskDefinition.find_by(unit_id: unit.id, abbreviation: abbreviation)

    result = TaskDefinition.find_by(unit_id: unit.id, name: name) if result.nil?

    if result.nil?
      # Remember creation triggers project task updates... so need correct weight
      result = TaskDefinition.find_or_create_by(unit_id: unit.id, tutorial_stream: tutorial_stream, name: name, abbreviation: abbreviation) do |td|
        td.target_date = target_date
        td.start_date = start_date
        td.weighting = row[:weighting].to_i
      end
      new_task = true
    end

    result.name                        = name
    result.unit_id                     = unit.id
    result.abbreviation                = abbreviation
    result.description                 = "#{row[:description]}".strip
    result.weighting                   = row[:weighting].to_i
    result.target_grade                = row[:target_grade].to_i
    result.restrict_status_updates     = %w(Yes y Y yes true TRUE 1).include? "#{row[:restrict_status_updates]}".strip
    result.max_quality_pts             = row[:max_quality_pts].to_i
    result.is_graded                   = %w(Yes y Y yes true TRUE 1).include? "#{row[:is_graded]}".strip
    result.start_date                  = start_date
    result.target_date                 = target_date
    unless row[:upload_requirements].nil?
      upload_requirements = JSON.parse(row[:upload_requirements])
      result.upload_requirements = normalize_upload_requirement_keys(upload_requirements)
    end
    result.due_date                    = due_date

    result.scorm_enabled               = %w(Yes y Y yes true TRUE 1).include? "#{row[:scorm_enabled]}".strip
    result.scorm_allow_review          = %w(Yes y Y yes true TRUE 1).include? "#{row[:scorm_allow_review]}".strip
    result.scorm_bypass_test           = %w(Yes y Y yes true TRUE 1).include? "#{row[:scorm_bypass_test]}".strip
    result.scorm_time_delay_enabled    = %w(Yes y Y yes true TRUE 1).include? "#{row[:scorm_time_delay_enabled]}".strip
    result.scorm_attempt_limit         = row[:scorm_attempt_limit].to_i

    result.plagiarism_warn_pct         = row[:plagiarism_warn_pct].to_i

    if row[:group_set].present?
      result.group_set = unit.group_sets.where(name: row[:group_set]).first
    end

    if row[:tutorial_stream].present?
      result.tutorial_stream = unit.tutorial_streams.where(abbreviation: row[:tutorial_stream]).first
    end

    import_discussion_prompts_from_csv_row(result, row)
    import_overseer_steps_from_csv_row(result, row)

    result.assess_in_portfolio_only = %w(Yes y Y yes true TRUE 1).include? "#{row[:assess_in_portfolio_only]}".strip

    if result.valid? && (row[:group_set].blank? || result.group_set.present?)
      begin
        result.save
      rescue
        result.destroy
        return [nil, false, 'Failed to save definition due to data error.']
      end
    else
      # delete the task if it was new
      result.destroy if new_task
      if result.group_set.nil? && row[:group_set].present?
        return [nil, false, "Unable to find groupset with name #{row[:group_set]} in unit."]
      else
        return [nil, false, result.errors.full_messages.join('. ')]
      end
    end

    [result, new_task, new_task ? "Added new task definition #{result.abbreviation}." : "Updated existing task #{result.abbreviation}"]
  end

  def self.normalize_upload_requirement_keys(upload_requirements)
    return upload_requirements unless upload_requirements.is_a?(Array)

    upload_requirements.map.with_index do |requirement, idx|
      next requirement unless requirement.is_a?(Hash)

      requirement.merge('key' => "file#{idx}")
    end
  end

  def self.import_discussion_prompts_from_csv_row(task_definition, row)
    task_definition.discussion_prompts.destroy_all
    return if row[:discussion_prompts].blank?

    prompts = JSON.parse(row[:discussion_prompts])
    prompts.each do |prompt|
      DiscussionPrompt.create!({
                                 task_definition: task_definition,
                                 content: prompt['content'],
                                 priority: prompt['priority']
                               })
    end
  end

  def self.import_overseer_steps_from_csv_row(task_definition, row)
    task_definition.overseer_steps.destroy_all
    return if row[:overseer_steps].blank?

    JSON.parse(row[:overseer_steps]).each do |step|
      OverseerStep.create!(
        task_definition: task_definition,
        name: step['name'],
        description: step['description'],
        display_name: step['display_name'],
        display_description: step['display_description'],
        run_command: step['run_command'],
        timeout: step['timeout'],
        sort_order: step['sort_order'],
        step_type: step['step_type'],
        partial_output_diff: step['partial_output_diff'],
        stdin_input_file: step['stdin_input_file'],
        expected_output_file: step['expected_output_file'],
        feedback_message: step['feedback_message'],
        status_on_success_id: status_id_from_csv(step['status_on_success']),
        status_on_failure_id: status_id_from_csv(step['status_on_failure']),
        halt_on_success: step['halt_on_success'],
        halt_on_failure: step['halt_on_failure'],
        show_expected_output: step['show_expected_output'],
        show_stdin: step['show_stdin'],
        show_stdout: step['show_stdout'],
        enabled: step.key?('enabled') ? step['enabled'] : true
      )
    end
  end

  def self.status_id_from_csv(value)
    return nil if value.blank?

    TaskStatus.status_for_name(value)&.id || TaskStatus.find_by(id: value.to_i)&.id
  end

  def is_group_task?
    !group_set.nil?
  end

  def has_task_resources?
    File.exist? task_resources(false)
  end

  def has_task_assessment_resources?
    File.exist? task_assessment_resources(false)
  end

  def has_task_assessment_script?
    File.exist? task_assessment_script(false)
  end

  def has_task_sheet?
    File.exist? task_sheet(false)
  end

  def has_scorm_data?
    File.exist? task_scorm_data
  end

  def scorm_enabled?
    scorm_enabled
  end

  def scorm_allow_review?
    scorm_allow_review
  end

  def scorm_bypass_test?
    scorm_bypass_test
  end

  def scorm_time_delay_enabled?
    scorm_time_delay_enabled
  end

  def scorm_attempt_limit?
    scorm_attempt_limit
  end

  def has_jplag_report?
    File.exist? jplag_report
  end

  def is_graded?
    is_graded
  end

  def has_stars?
    max_quality_pts > 0
  end

  def add_task_sheet(file)
    FileUtils.mv file, task_sheet
  end

  def remove_task_sheet()
    if has_task_sheet?
      FileUtils.rm task_sheet
    end
  end

  # Move task resources into place
  def add_task_resources(file, copy: false)
    if copy
      FileUtils.cp file, task_resources
    else
      FileUtils.mv file, task_resources
    end

    # If TII is enabled, then we need to great group attachments
    if tii_checks?
      send_group_attachments_to_tii
    end
  end

  def remove_task_resources()
    if has_task_resources?
      FileUtils.rm task_resources

      tii_group_attachments.destroy_all if tii_checks?
    end
  end

  def add_task_assessment_resources(file)
    FileUtils.mv file, task_assessment_resources
    # TODO: Use FACL instead in future.
    `chmod 755 #{task_assessment_resources}`
  end

  def remove_task_assessment_resources()
    if has_task_assessment_resources?
      FileUtils.rm task_assessment_resources
    end
  end

  def add_scorm_data(file, copy: false)
    if copy
      FileUtils.cp file, task_scorm_data
    else
      FileUtils.mv file, task_scorm_data
    end
  end

  def remove_scorm_data()
    if has_scorm_data?
      FileUtils.rm task_scorm_data
    end

    reset_scorm_config()
  end

  # Get the path to the task sheet - using the current abbreviation
  def task_sheet(create = true)
    task_sheet_with_abbreviation(abbreviation, create)
  end

  def task_resources(create = true)
    task_resources_with_abbreviation(abbreviation, create)
  end

  def task_assessment_resources(create = true)
    task_assessment_resources_with_abbreviation(abbreviation, create)
  end

  def overseer_resource_files
    return [] unless File.exist?(task_assessment_resources)

    files = []
    Zip::File.open(task_assessment_resources) do |zip_file|
      zip_file.each do |entry|
      next if entry.directory?
      # skip macOS metadata files and hidden files
      next if File.basename(entry.name).start_with?('._', '.')

      # remove top-level folder
      parts = entry.name.split('/', 2)
      files << "/#{parts.last}" unless parts.empty?
      end
    end
    files
  end

  def task_assessment_script(create = true)
    task_assessment_script_with_abbreviation(abbreviation, create)
  end

  def task_scorm_data(create = true)
    task_scorm_data_with_abbreviation(abbreviation, create)
  end

  def jplag_report
    task_jplag_report_with_abbreviation(abbreviation)
  end

  def related_tasks_with_files(consolidate_groups = true)
    tasks_with_files = tasks.select(&:has_pdf)

    if is_group_task? && consolidate_groups
      # group task so only select one member of each group
      seen_groups = []

      tasks_with_files = tasks_with_files.select do |t|
        if t.group.nil?
          result = false
        else
          result = seen_groups.exclude?(t.group)
          seen_groups << t.group if result
        end
        result
      end
    end

    tasks_with_files
  end

  # Read a file from the task definition resources.
  #
  # @param filename [String] The name of the file to read from the zipfile.
  # @return [String] The contents of the file, or nil if the file does not exist.
  def read_file_from_resources(filename)
    return nil unless has_task_resources?

    Zip::File.open(task_resources) do |zip_file|
      entry = zip_file.glob(filename).first
      return entry.get_input_stream.read if entry
    end

    nil
  end

  private

  def target_grade_enabled_for_unit
    return if unit.nil? || target_grade.nil? || unit.grade_value?(target_grade)

    errors.add(:target_grade, 'is not enabled for this unit')
  end

  def delete_associated_files()
    remove_task_sheet()
    remove_task_resources()
    remove_task_assessment_resources()
    remove_scorm_data()
  end

  # Calculate the path to the task sheet using the provided abbreviation
  # This allows the path to be calculated on abbreviation change to allow files to
  # be moved
  def task_sheet_with_abbreviation(abbr, create = true)
    task_path = FileHelper.task_file_dir_for_unit unit, create

    result_with_sanitised_path = "#{task_path}#{FileHelper.sanitized_path(abbr)}.pdf"
    result_with_sanitised_file = "#{task_path}#{FileHelper.sanitized_filename(abbr)}.pdf"

    if File.exist? result_with_sanitised_path
      result_with_sanitised_path
    else
      result_with_sanitised_file
    end
  end

  # Calculate the path to the task sheet using the provided abbreviation
  # This allows the path to be calculated on abbreviation change to allow files to
  # be moved
  def task_resources_with_abbreviation(abbr, create = true)
    task_path = FileHelper.task_file_dir_for_unit unit, create

    result_with_sanitised_path = "#{task_path}#{FileHelper.sanitized_path(abbr)}.zip"
    result_with_sanitised_file = "#{task_path}#{FileHelper.sanitized_filename(abbr)}.zip"

    if File.exist? result_with_sanitised_path
      result_with_sanitised_path
    else
      result_with_sanitised_file
    end
  end

  def task_assessment_resources_with_abbreviation(abbr, create = true)
    task_path = FileHelper.task_file_dir_for_unit unit, create

    result_with_sanitised_path = "#{task_path}#{FileHelper.sanitized_path(abbr)}-assessment.zip"
    result_with_sanitised_file = "#{task_path}#{FileHelper.sanitized_filename(abbr)}-assessment.zip"

    if File.exist? result_with_sanitised_path
      result_with_sanitised_path
    else
      result_with_sanitised_file
    end
  end

  def task_assessment_script_with_abbreviation(abbr, create = true)
    task_path = FileHelper.task_file_dir_for_unit unit, create

    result_with_sanitised_path = "#{task_path}#{FileHelper.sanitized_path(abbr)}-assessment-script.txt"
    result_with_sanitised_file = "#{task_path}#{FileHelper.sanitized_filename(abbr)}-assessment-script.txt"

    # TODO: currently its saving 1_P instead of 1.1P
    if !File.exist?(result_with_sanitised_path) && create
      FileUtils.mkdir_p(File.dirname(result_with_sanitised_path))
      File.write(result_with_sanitised_path, '')
    end

    if File.exist? result_with_sanitised_path
      result_with_sanitised_path
    else
      result_with_sanitised_file
    end
  end

  # Calculate the path to the SCORM containzer zip file using the provided abbreviation
  # This allows the path to be calculated on abbreviation change to allow files to
  # be moved
  def task_scorm_data_with_abbreviation(abbr, create = true)
    task_path = FileHelper.task_file_dir_for_unit unit, create

    result_with_sanitised_path = "#{task_path}#{FileHelper.sanitized_path(abbr)}.scorm.zip"
    result_with_sanitised_file = "#{task_path}#{FileHelper.sanitized_filename(abbr)}.scorm.zip"

    if File.exist? result_with_sanitised_path
      result_with_sanitised_path
    else
      result_with_sanitised_file
    end
  end

  def task_jplag_report_with_abbreviation(abbr)
    task_path = FileHelper.task_jplag_report_dir unit

    result_with_sanitised_path = "#{task_path}#{FileHelper.sanitized_path(abbr)}-result.jplag"
    result_with_sanitised_file = "#{task_path}#{FileHelper.sanitized_filename(abbr)}-result.jplag"

    if File.exist? result_with_sanitised_path
      result_with_sanitised_path
    else
      result_with_sanitised_file
    end
  end

  def reset_scorm_config()
    self.scorm_enabled = false
    self.scorm_allow_review = false
    self.scorm_bypass_test = false
    self.scorm_time_delay_enabled = false
    self.scorm_attempt_limit = 0
  end
end
