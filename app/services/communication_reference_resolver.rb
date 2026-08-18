# Translates the unit-scoped foreign keys on communication conditions and actions
# to and from portable natural keys, so that a rule authored in one unit can be
# rebuilt in another.
#
# A reference that cannot be resolved in the target unit is never silently
# dropped -- it is written back to the record's +unresolved_references+ so the
# rule can be flagged in the editor and blocked from executing until a human
# repoints it.
class CommunicationReferenceResolver
  # Reference name => the attribute holding the foreign key.
  REFERENCE_ATTRIBUTES = {
    'task_definition' => :task_definition_id,
    'tutorial' => :tutorial_id,
    'tutorial_stream' => :tutorial_stream_id,
    'campus' => :campus_id
  }.freeze

  # The references each communication type cannot operate without. A record of
  # one of these types with a blank reference matches on fallback values (a
  # missing task reads as 'not_started', a missing campus makes
  # 'not_enrolled_in' true for everyone), so it must be treated as broken.
  # Where each reference is looked up in the target unit, and which natural keys
  # to try in order. Tutorial abbreviations are unique per unit, so the campus in
  # a tutorial descriptor is a display hint rather than part of the lookup -- a
  # tutorial that changed campus should still match. Campuses are global rather
  # than unit scoped.
  LOOKUPS = {
    'task_definition' => { scope: ->(unit) { unit.task_definitions }, keys: %w[abbreviation name] },
    'tutorial' => { scope: ->(unit) { unit.tutorials }, keys: %w[abbreviation] },
    'tutorial_stream' => { scope: ->(unit) { unit.tutorial_streams }, keys: %w[abbreviation name] },
    'campus' => { scope: ->(_unit) { Campus }, keys: %w[abbreviation name] }
  }.freeze

  REQUIRED_REFERENCES = {
    'TaskDefinitionStatusCondition' => 'task_definition',
    'TutorialEnrolmentCondition' => 'tutorial',
    'TutorialStreamEnrolmentCondition' => 'tutorial_stream',
    'CampusCondition' => 'campus',
    'TaskCommentAction' => 'task_definition'
  }.freeze

  class << self
    # The reference names a record of this type carries, whether or not they are
    # currently populated.
    def reference_names_for(type)
      Array(REQUIRED_REFERENCES[type.to_s])
    end

    def required_reference_for(type)
      REQUIRED_REFERENCES[type.to_s]
    end

    # Builds the portable descriptor for every reference a record holds, e.g.
    #   { 'task_definition' => { 'abbreviation' => 'T1.1', 'name' => 'Hello World' } }
    #
    # A reference that is already unresolved on the source record is carried
    # through unchanged, so exporting a broken rule and importing it elsewhere
    # preserves what the author originally pointed at.
    def describe(record)
      reference_names_for(record.type).each_with_object({}) do |name, described|
        existing = unresolved_descriptor(record, name)
        if existing.present?
          described[name] = existing
          next
        end

        target = record.public_send(name)
        described[name] = descriptor_for(name, target) if target.present?
      end
    end

    # Applies portable descriptors to a record for +unit+, populating the
    # foreign key where the reference resolves and recording it as unresolved
    # where it does not.
    #
    # Returns the list of descriptors that could not be resolved.
    def apply(record, descriptors, unit)
      unresolved = {}

      reference_names_for(record.type).each do |name|
        descriptor = stringify(descriptors)[name]

        if descriptor.blank?
          record.public_send("#{REFERENCE_ATTRIBUTES[name]}=", nil)
          next
        end

        target = find(name, descriptor, unit)

        if target.present?
          record.public_send("#{REFERENCE_ATTRIBUTES[name]}=", target.id)
        else
          record.public_send("#{REFERENCE_ATTRIBUTES[name]}=", nil)
          unresolved[name] = descriptor
        end
      end

      record.unresolved_references = unresolved.presence
      unresolved
    end

    # True when the record is missing a reference it cannot operate without.
    # Covers both records flagged during an import and pre-existing records
    # whose reference was nulled by an earlier rollover.
    def unresolved?(record)
      required = required_reference_for(record.type)
      return false if required.nil?

      stringify(record.unresolved_references)[required].present? ||
        record.public_send(REFERENCE_ATTRIBUTES[required]).blank?
    end

    # A human-readable description of what a broken record was pointing at,
    # for display in the editor. Falls back to the reference name when the
    # record predates unresolved_references and carries no descriptor.
    def unresolved_summary(record)
      return nil unless unresolved?(record)

      name = required_reference_for(record.type)
      descriptor = stringify(record.unresolved_references)[name]

      {
        'reference' => name,
        'descriptor' => descriptor,
        'label' => descriptor_label(name, descriptor)
      }
    end

    private

    def descriptor_for(name, target)
      # A tutorial has no name of its own, so its campus travels instead -- as a
      # hint for the editor, not as part of the lookup.
      return { 'abbreviation' => target.abbreviation, 'campus' => target.campus&.abbreviation } if name == 'tutorial'

      { 'abbreviation' => target.abbreviation, 'name' => target.name }
    end

    def find(name, descriptor, unit)
      lookup = LOOKUPS[name]
      return nil if lookup.nil?

      descriptor = stringify(descriptor)
      scope = lookup[:scope].call(unit)

      lookup[:keys].lazy.filter_map do |key|
        value = descriptor[key].presence
        scope.find_by(key => value) if value
      end.first
    end

    def descriptor_label(name, descriptor)
      descriptor = stringify(descriptor)
      label = [descriptor['abbreviation'], descriptor['name']].compact_blank.join(' ')
      return name.humanize if label.blank?

      "#{name.humanize}: #{label}"
    end

    def unresolved_descriptor(record, name)
      stringify(record.unresolved_references)[name]
    end

    def stringify(value)
      return {} if value.blank?

      value.respond_to?(:deep_stringify_keys) ? value.deep_stringify_keys : value
    end
  end
end
