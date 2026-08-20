# Moves communication sets and rules between units as a JSON document, so staff
# can copy a set in one unit and paste it into another.
#
# The document carries abbreviations instead of database ids. On import each one
# is looked up in the target unit; a reference with no equivalent there is left
# nil rather than failing the import, so the rule keeps its conditions and
# actions. CommunicationRule#unresolved? then flags it in the editor and the set
# is blocked from running until someone repoints it.
class CommunicationTransfer
  class InvalidDocument < StandardError; end

  VERSION = 1
  SET_FORMAT = 'ontrack.communication_set'.freeze
  RULE_FORMAT = 'ontrack.communication_rule'.freeze

  SCHEDULE_ATTRIBUTES = %w[
    name active anchor_week anchor_day hour minute timezone recurrence interval repeat_count until_at
  ].freeze
  RULE_ATTRIBUTES = %w[name operator position active send_log_to_convenors].freeze
  CONDITION_ATTRIBUTES = %w[
    type operator target_grade task_statuses task_status_count task_target_grade
    activity_days spec_con_days submitted_portfolio
  ].freeze
  ACTION_ATTRIBUTES = %w[type subject body email_tutors email_convenors target_grade].freeze

  # Where each reference is looked up in the target unit. Campuses are shared
  # between units; everything else is unit scoped.
  SCOPES = {
    task_definition: ->(unit) { unit.task_definitions },
    tutorial: ->(unit) { unit.tutorials },
    tutorial_stream: ->(unit) { unit.tutorial_streams },
    campus: ->(_unit) { Campus }
  }.freeze

  class << self
    def export_set(set)
      envelope(SET_FORMAT, set.unit).merge(
        'set' => {
          'name' => set.name,
          'active' => set.active,
          'schedules' => set.communication_set_schedules.map { |schedule| attributes_of(schedule, SCHEDULE_ATTRIBUTES) },
          'rules' => set.communication_rules.map { |rule| rule_document(rule) }
        }
      )
    end

    def export_rule(rule)
      envelope(RULE_FORMAT, rule.unit).merge('rule' => rule_document(rule))
    end

    def import_set(document, unit)
      document = expect!(document, SET_FORMAT)['set']
      raise InvalidDocument, 'Document is missing its communication set' if document.blank?

      ApplicationRecord.transaction do
        set = unit.communication_sets.create!(
          name: available_name(unit, document['name']),
          active: document.fetch('active', true)
        )

        Array(document['schedules']).each do |schedule|
          # Imported schedules arrive switched off. The schedule runner is the
          # one place an active flag is honoured, so this is what stops a set
          # mailing students before anyone has looked at it.
          set.communication_set_schedules.create!(schedule.slice(*SCHEDULE_ATTRIBUTES).merge('active' => false))
        end

        Array(document['rules']).each_with_index { |rule, index| build_rule(set, rule, index) }
        set
      end
    end

    def import_rule(document, set)
      document = expect!(document, RULE_FORMAT)['rule']
      raise InvalidDocument, 'Document is missing its communication rule' if document.blank?

      ApplicationRecord.transaction { build_rule(set, document, set.communication_rules.count) }
    end

    private

    def envelope(format, unit)
      {
        'format' => format,
        'version' => VERSION,
        'exported_at' => Time.zone.now.iso8601,
        'source' => { 'unit_code' => unit.code, 'teaching_period' => unit.teaching_period&.detailed_name }
      }
    end

    def rule_document(rule)
      attributes_of(rule, RULE_ATTRIBUTES).merge(
        'conditions' => rule.communication_conditions.map { |condition| record_document(condition, CONDITION_ATTRIBUTES) },
        'actions' => rule.communication_actions.map { |action| record_document(action, ACTION_ATTRIBUTES) }
      )
    end

    def record_document(record, attributes)
      document = attributes_of(record, attributes)
      reference = record.required_reference
      target = reference && record.public_send(reference)
      document['reference'] = { reference.to_s => target.abbreviation } if target

      document
    end

    def attributes_of(record, attributes)
      attributes.index_with { |attribute| record.public_send(attribute) }
    end

    def build_rule(set, document, position)
      rule = set.communication_rules.create!(document.slice(*RULE_ATTRIBUTES).merge('position' => position))

      Array(document['conditions']).each do |condition|
        build_record(rule.communication_conditions, condition, CONDITION_ATTRIBUTES, rule)
      end

      Array(document['actions']).each do |action|
        build_record(rule.communication_actions, action, ACTION_ATTRIBUTES, rule)
      end

      rule
    end

    def build_record(association, document, attributes, rule)
      record = association.new(document.slice(*attributes))
      reference = record.required_reference

      if reference.present?
        abbreviation = document.dig('reference', reference.to_s)
        record.public_send("#{reference}=", find_reference(reference, abbreviation, rule.unit))
      end

      record.save!
    rescue ActiveRecord::RecordInvalid => e
      # Not everything that fails here is a missing reference -- units enable
      # different target grades, so a grade-based rule can be valid where it was
      # written and invalid here. Name the rule rather than the bare model.
      raise InvalidDocument, "Rule '#{rule.name}' cannot be used in this unit: #{e.record.errors.full_messages.join(', ')}"
    end

    def find_reference(reference, abbreviation, unit)
      return nil if abbreviation.blank?

      SCOPES.fetch(reference).call(unit).find_by(abbreviation: abbreviation)
    end

    def expect!(document, format)
      document = document.deep_stringify_keys if document.respond_to?(:deep_stringify_keys)
      raise InvalidDocument, "Expected a #{format} document" unless document.is_a?(Hash) && document['format'] == format
      raise InvalidDocument, "Unsupported document version #{document['version'].inspect}" unless document['version'] == VERSION

      document
    end

    # Pasting a set back into the unit it came from is a fair way to duplicate
    # it, so a clashing name is suffixed rather than rejected.
    def available_name(unit, name)
      name = name.presence || 'Communication set'
      return name unless unit.communication_sets.exists?(name: name)

      counter = 2
      counter += 1 while unit.communication_sets.exists?(name: "#{name} (#{counter})")
      "#{name} (#{counter})"
    end
  end
end
