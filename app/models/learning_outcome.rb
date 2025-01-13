class LearningOutcome < ApplicationRecord
  include ApplicationHelper

  def self.permissions
    convenor_role_permissions = [
      :update,
      :get_los,
      :update_glos,
      :upload_csv
    ]

    admin_role_permissions = [
      :update,
      :get_los,
      :update_glos,
      :upload_csv
    ]

    tutor_role_permissions = [
      :update,
      :get_los,
      :update_glos
    ]

    nil_role_permissions = []

    {
      convenor: convenor_role_permissions,
      admin: admin_role_permissions,
      tutor: tutor_role_permissions,
      nil: nil_role_permissions
    }
  end

  def role_for(user)
    if user.has_admin_capability?
      Role.admin
    elsif user.has_convenor_capability?
      Role.convenor
    elsif user.has_tutor_capability?
      Role.tutor
    else
      nil
    end
  end

=begin
  def role_for(user)
    return :admin if user.has_admin_capability?
    return :convenor if user.has_convenor_capability?
    return :tutor if user.has_tutor_capability?

    return nil
  end
=end

=begin
  def role_for(user)
    if convenors.where('unit_roles.user_id=:id', id: user.id).count == 1
      Role.convenor
    elsif tutors.where('unit_roles.user_id=:id', id: user.id).count == 1
      Role.tutor
    elsif active_projects.where('projects.user_id=:id', id: user.id).count == 1
      Role.student
    elsif user.has_auditor_capability? &&
          start_date >= Time.zone.today - Doubtfire::Application.config.auditor_unit_access_years &&
          end_date < DateTime.now
      Role.auditor
    elsif user.has_admin_capability?
      Role.admin
    else
      nil
    end
  end
=end
  belongs_to :context, polymorphic: true, optional: true

  has_many :outgoing_links, class_name: 'LearningOutcomeLink', foreign_key: 'source_id', dependent: :destroy
  has_many :linked_outcomes, through: :outgoing_links, source: :target

  has_many :incoming_links, class_name: 'LearningOutcomeLink', foreign_key: 'target_id', dependent: :destroy
  has_many :linked_by_outcomes, through: :incoming_links, source: :source

  has_many :feedback_group_chips, class_name: 'Feedback::FeedbackGroupChip', dependent: :destroy
  has_many :feedback_template_chips, class_name: 'Feedback::FeedbackTemplateChip', dependent: :destroy

  has_many :learning_outcome_task_links, dependent: :destroy # links to learning outcomes
  has_many :related_task_definitions, -> { where('learning_outcome_task_links.task_id is NULL') }, through: :learning_outcome_task_links, source: :task_definition # only link staff relations

  validates :short_description, length: { maximum: 4095, allow_blank: true }
  validates :full_outcome_description, length: { maximum: 4095, allow_blank: true }

  def self.csv_header
    %w(context_type, context_id, abbreviation, short_description, full_outcome_description, linked_outcome_ids)
  end

  def add_csv_row(row)
    row << [context_type, context_id, abbreviation, short_description, full_outcome_description, linked_outcome_ids]
  end

  def self.create_from_csv(context, row, result)
    context_type = row['context_type']
    context_id = row['context_id'].to_i

    if context_type != context.class.name || context_id != context.id
      result[:ignored] << { row: row, message: "Invalid context. #{context_type} #{context_id} does not match #{context.class.name} #{context.id}" }
      return
    end

    abbreviation = row['abbreviation']
    if abbreviation.nil?
      result[:errors] << { row: row, message: 'Missing abbreviation' }
      return
    end

    short_description = row['short_description']
    if short_description.nil?
      result[:errors] << { row: row, message: 'Missing short_description' }
      return
    end

    full_outcome_description = row['full_outcome_description']
    if full_outcome_description.nil?
      result[:errors] << { row: row, message: 'Missing full_outcome_description' }
      return
    end

    outcome = LearningOutcome.find_or_create_by(context_id: context_id, context_type: context_type, abbreviation: abbreviation) do |outcome|
      outcome.short_description = short_description
      outcome.full_outcome_description = full_outcome_description
      outcome.linked_outcome_ids = row['linked_outcome_ids'].split(',').map(&:to_i)
    end

    outcome.save!

    result[:success] << if outcome.new_record?
                          { row: row, message: "Outcome #{abbreviation} created" }
                        else
                          { row: row, message: "Outcome #{abbreviation} updated" }
                        end
  end

  def export_feedback_chips_to_csv
    CSV.generate do |row|
      row << FeedbackChip.csv_header
      feedback_chips.each do |chip|
        chip.add_csv_row row
      end
    end
  end

  def import_feedback_chips_from_csv(file)
    result = {
      success: [],
      errors: [],
      ignored: []
    }

    data = read_file_to_str(file)

    CSV.parse(data,
              headers: true,
              header_converters: [->(i) { i.nil? ? '' : i }, :downcase, ->(hdr) { hdr.strip unless hdr.nil? }],
              converters: [->(body) { body.encode!('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '') unless body.nil? }]).each do |row|
      # Make sure we're not looking at the header or an empty line
      next if row[0] =~ /type/

      begin
        FeedbackChip.create_from_csv(self, row, result)
      rescue Exception => e
        result[:errors] << { row: row, message: e.message.to_s }
      end
    end

    result
  end

end
