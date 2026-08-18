# Rebuilds a communication set, or a single communication rule, from a document
# produced by CommunicationSetExporter.
#
# References that exist in the source unit but not in the target unit are kept
# as placeholders on the imported record rather than being dropped. The record
# is then reported as unresolved, the editor flags it, and the set is blocked
# from executing until a human repoints or removes it -- a silently nulled
# reference would otherwise widen the rule (a missing task reads as
# 'not_started') and mail the entire unit.
class CommunicationSetImporter
  class InvalidDocument < StandardError; end

  SUPPORTED_VERSIONS = [CommunicationSetExporter::FORMAT_VERSION].freeze

  attr_reader :document, :unit

  def initialize(document, unit)
    @document = stringify(document)
    @unit = unit
    @unresolved = []
    @warnings = []
  end

  # Creates a new communication set in the unit from a set document.
  def import_set(dry_run: false)
    expect_format!(CommunicationSetExporter::SET_FORMAT)
    set_document = document['set']
    raise InvalidDocument, 'Document is missing its communication set' if set_document.blank?

    run(dry_run) do
      communication_set = unit.communication_sets.create!(
        name: available_set_name(set_document['name']),
        active: set_document.fetch('active', true)
      )

      Array(set_document['schedules']).each do |schedule_document|
        build_schedule(communication_set, schedule_document)
      end

      Array(set_document['rules']).each_with_index do |rule_document, index|
        build_rule(communication_set, rule_document, index)
      end

      communication_set
    end
  end

  # Appends a rule from a rule document to an existing communication set.
  def import_rule(communication_set, dry_run: false)
    expect_format!(CommunicationSetExporter::RULE_FORMAT)
    rule_document = document['rule']
    raise InvalidDocument, 'Document is missing its communication rule' if rule_document.blank?

    run(dry_run) do
      build_rule(communication_set, rule_document, communication_set.communication_rules.count)
    end
  end

  # Describes what the import did, or -- for a dry run -- what it would do.
  def report(record = nil)
    {
      format: document['format'],
      version: document['version'],
      source: document['source'],
      imported_id: record&.id,
      imported_name: record.try(:name),
      unresolved_count: @unresolved.length,
      unresolved: @unresolved,
      warnings: @warnings.uniq
    }
  end

  private

  def run(dry_run)
    record = nil

    ApplicationRecord.transaction do
      record = yield
      raise ActiveRecord::Rollback if dry_run
    end

    report(dry_run ? nil : record)
  end

  def expect_format!(format)
    raise InvalidDocument, 'Not an OnTrack communication document' if document['format'].blank?

    if document['format'] != format
      raise InvalidDocument,
            "Expected a #{format} document but received #{document['format']}"
    end

    return if SUPPORTED_VERSIONS.include?(document['version'])

    raise InvalidDocument,
          "Unsupported document version #{document['version'].inspect}"
  end

  def build_schedule(communication_set, schedule_document)
    schedule_document = stringify(schedule_document)

    # Schedules always arrive switched off. The schedule runner is the one place
    # that does honour an active flag, so this is what stops an imported set
    # mailing students before anyone has reviewed it.
    communication_set.communication_set_schedules.create!(
      schedule_document.slice(*CommunicationSetExporter::SCHEDULE_ATTRIBUTES).merge('active' => false)
    )

    @warnings << 'Imported schedules are inactive until you enable them.'
    return if schedule_document['until_at'].blank?

    @warnings << 'A schedule carries an absolute end date from the source unit -- check it against this unit\'s teaching period.'
  end

  def build_rule(communication_set, rule_document, position)
    rule_document = stringify(rule_document)

    rule = communication_set.communication_rules.create!(
      rule_document.slice(*CommunicationSetExporter::RULE_ATTRIBUTES).merge('position' => position)
    )

    Array(rule_document['conditions']).each do |condition_document|
      build_child(rule.communication_conditions, condition_document, CommunicationSetExporter::CONDITION_ATTRIBUTES, rule, 'condition')
    end

    Array(rule_document['actions']).each do |action_document|
      build_child(rule.communication_actions, action_document, CommunicationSetExporter::ACTION_ATTRIBUTES, rule, 'action')
    end

    rule
  end

  def build_child(association, child_document, attributes, rule, kind)
    child_document = stringify(child_document)

    record = association.new(child_document.slice(*attributes))
    unresolved = CommunicationReferenceResolver.apply(record, child_document['references'], unit)

    begin
      record.save!
    rescue ActiveRecord::RecordInvalid => e
      # Not everything that fails here is a missing reference -- units enable
      # different target grades, so a grade-based rule can be valid in the
      # source unit and invalid here. Name the rule so it can be fixed rather
      # than surfacing a bare model error.
      raise InvalidDocument,
            "Rule '#{rule.name}' has a #{kind} (#{record.type}) that is not valid in this unit: #{e.record.errors.full_messages.join(', ')}"
    end

    unresolved.each do |reference, descriptor|
      @unresolved << {
        rule_name: rule.name,
        kind: kind,
        type: record.type,
        reference: reference,
        descriptor: descriptor,
        label: [descriptor['abbreviation'], descriptor['name']].compact_blank.join(' ').presence || reference.humanize
      }
    end
  end

  # Importing into the unit a set came from is a legitimate way to duplicate it,
  # so a clashing name is suffixed rather than rejected.
  def available_set_name(name)
    name = name.presence || 'Imported communication set'
    return name unless unit.communication_sets.exists?(name: name)

    counter = 2
    counter += 1 while unit.communication_sets.exists?(name: "#{name} (#{counter})")
    "#{name} (#{counter})"
  end

  def stringify(value)
    return {} if value.blank?

    value.respond_to?(:deep_stringify_keys) ? value.deep_stringify_keys : value
  end
end
