FactoryGirl.define do
  factory :project do
    unit
    campus
    user

    after(:create) do |project|
      tutorial = FactoryGirl.create(:tutorial, campus: project.campus)
      create_list(:tutorial_enrolment, 1, project: project, tutorial: tutorial)
    end
  end
end
