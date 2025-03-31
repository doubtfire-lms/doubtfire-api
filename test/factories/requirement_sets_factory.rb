FactoryBot.define do
  factory :requirement_set, class: 'Courseflow::RequirementSet'do
    requirementSetGroupId { 1 }
    description { "set description" }
    unitId { 1 }
    requirementId { 1 }
  end
end
