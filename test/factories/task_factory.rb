FactoryBot.define do
  factory :task do
    project { FactoryBot.create(:project) }
    task_definition { project.unit.task_definitions.first }
    task_status { TaskStatus.not_started }
  end
end
