# Shared behaviour for communication conditions and actions that point at
# unit-scoped records (task definitions, tutorials, tutorial streams, campuses).
#
# When a rule is imported into a unit that has no equivalent record, the
# reference is kept as a descriptor in +unresolved_references+ instead of being
# nulled. That descriptor is what lets the subclass presence validations stand
# down for an imported placeholder while still rejecting a reference-less record
# created through the normal editor.
module CommunicationReferences
  extend ActiveSupport::Concern

  included do
    attribute :unresolved_references, :json
  end

  # True only for a placeholder left by an import -- not for a record whose
  # reference has merely gone missing. Guards the presence validations.
  def unresolved_reference?
    unresolved_references.present?
  end

  # True whenever this record cannot be evaluated: an import placeholder, or a
  # reference whose target has since been deleted (there are no foreign keys on
  # these columns, so a deleted task definition leaves the id dangling).
  def unresolved?
    CommunicationReferenceResolver.unresolved?(self)
  end

  # Describes what this record is missing, for the editor to display.
  def unresolved_summary
    CommunicationReferenceResolver.unresolved_summary(self)
  end
end
