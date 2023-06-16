
FactoryBot.define do
    factory :criterion do
        transient do
            number_of_criterion_options {0}
        end

        stage

        sequence(:order)            { |n| n }
        description                 { Faker::Lorem.sentence }
        help_text                   { Faker::Lorem.sentence }

        after(:create) do |criterion, evaluator|
            create_list(:criterion_option, evaluator.number_of_criterion_options, criterion: criterion)
        end
    end
end
