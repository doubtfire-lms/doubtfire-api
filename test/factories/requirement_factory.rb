FactoryBot.define do
  factory :requirement, class: 'Courseflow::Requirement' do
    unitId { FactoryBot.create(:unit).id }
    courseId { FactoryBot.create(:course).id }
    type { 'count' }
    category { 'prerequisite' }
    description { 'Must complete SIT102 first' }
    minimum { 1 }
    maximum { 1 }
    requirementSetGroupId { 1 }
  end
end
