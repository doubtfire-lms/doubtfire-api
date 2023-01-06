FactoryBot.define do
  factory :project do
    unit { create(:unit, with_students:false) }
    campus { Campus.offset(rand(Campus.count)).first || create(:campus) }
    task_stats { Project::DEFAULT_TASK_STATS }
    user
  end
end
