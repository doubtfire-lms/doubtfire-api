# Read about factories at https://github.com/thoughtbot/factory_bot

FactoryBot.define do
  factory :focus do
    transient do
      with_criteria               { :some } # :all, :some, :none
    end

  	sequence(:title) {|id| "Focus #{id}" }
    description { Faker::Lorem.paragraph }
    color { rand(0..14) }
    unit

    after :create do |focus, evaluator|
      if evaluator.with_criteria == :all || evaluator.with_criteria == :some
        GradeHelper::RANGE.each do |grade|
          if evaluator.with_criteria == :all || rand(1..10) <= 8 # 80% chance of creating a focus criterion for each grade
            focus.set_criteria grade, Faker::Lorem.sentence
          end
        end
      end
    end
  end
end
