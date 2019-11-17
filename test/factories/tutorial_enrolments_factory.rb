FactoryGirl.define do
  factory :tutorial_enrolment do
    # Get the campus to make sure it is same
    campus = FactoryGirl.build(:campus)

    association :tutorial, factory: :tutorial, campus: campus, strategy: :build
    association :project, factory: :project, campus: campus, strategy: :build
  end
end
