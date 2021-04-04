FactoryBot.define do
  factory :tutorial_enrolment do
    project

    after(:build) do |tutorial_enrolment|
      tutorial = FactoryBot.create(:tutorial, unit: tutorial_enrolment.project.unit, campus: tutorial_enrolment.project.campus)
      tutorial_enrolment.tutorial = tutorial
    end
  end
end
