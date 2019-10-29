FactoryGirl.define do
  factory :project do
    unit
    campus
    user

    after(:create) do |project|
      create_list(:tutorial_enrolment, 3, project: project)
    end
  end
end
