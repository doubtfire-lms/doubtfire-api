FactoryGirl.define do
  factory :project do
    unit
    campus
    user

    after(:build) do |project|
      project.tutorial = FactoryGirl.create(:tutorial, campus: project.campus, unit: project.unit)
    end
  end
end
