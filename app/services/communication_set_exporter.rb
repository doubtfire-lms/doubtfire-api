# Serialises a communication set, or a single communication rule, into a
# portable document that can be saved to a file and imported into another unit
# -- potentially on another OnTrack instance.
#
# The document holds no database identifiers. Every unit-scoped reference is
# written as a natural key (see CommunicationReferenceResolver) so that the
# importer can repoint it at the equivalent record in the target unit.
class CommunicationSetExporter
  FORMAT_VERSION = 1
  SET_FORMAT = 'ontrack.communication_set'.freeze
  RULE_FORMAT = 'ontrack.communication_rule'.freeze

  SCHEDULE_ATTRIBUTES = %w[
    name active anchor_week anchor_day hour minute timezone recurrence interval repeat_count until_at
  ].freeze

  RULE_ATTRIBUTES = %w[name operator position active send_log_to_convenors].freeze

  CONDITION_ATTRIBUTES = %w[
    type operator target_grade task_statuses task_status_count task_target_grade
    last_sign_in_at activity_days spec_con_days submitted_portfolio
  ].freeze

  ACTION_ATTRIBUTES = %w[type subject body email_tutors email_convenors target_grade].freeze

  def self.export_set(communication_set)
    new.export_set(communication_set)
  end

  def self.export_rule(communication_rule)
    new.export_rule(communication_rule)
  end

  def export_set(communication_set)
    envelope(SET_FORMAT, communication_set.unit).merge(
      'set' => {
        'name' => communication_set.name,
        'active' => communication_set.active,
        'schedules' => communication_set.communication_set_schedules.map { |schedule| schedule_document(schedule) },
        'rules' => communication_set.communication_rules.map { |rule| rule_document(rule) }
      }
    )
  end

  def export_rule(communication_rule)
    envelope(RULE_FORMAT, communication_rule.unit).merge(
      'rule' => rule_document(communication_rule)
    )
  end

  private

  def envelope(format, unit)
    {
      'format' => format,
      'version' => FORMAT_VERSION,
      'exported_at' => Time.zone.now.iso8601,
      'source' => {
        'unit_code' => unit.code,
        'unit_name' => unit.name,
        'teaching_period' => unit.teaching_period&.detailed_name
      }
    }
  end

  def rule_document(rule)
    document(rule, RULE_ATTRIBUTES).merge(
      'conditions' => rule.communication_conditions.map { |condition| record_document(condition, CONDITION_ATTRIBUTES) },
      'actions' => rule.communication_actions.map { |action| record_document(action, ACTION_ATTRIBUTES) }
    )
  end

  def schedule_document(schedule)
    document(schedule, SCHEDULE_ATTRIBUTES)
  end

  def record_document(record, attributes)
    references = CommunicationReferenceResolver.describe(record)
    body = document(record, attributes)
    body['references'] = references if references.present?
    body
  end

  def document(record, attributes)
    attributes.index_with { |attribute| serialise(record.public_send(attribute)) }
  end

  def serialise(value)
    value.respond_to?(:iso8601) ? value.iso8601 : value
  end
end
