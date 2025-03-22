FactoryBot.define do
  factory :feedback_group_chip, class: 'Feedback::FeedbackGroupChip' do
    chip_text { "GCT #{Faker::Lorem.word}" }
    description { Faker::Lorem.sentence }
    parent_chip_id { nil }
    learning_outcome_id { 1 }
  end

  factory :feedback_template_chip, class: 'Feedback::FeedbackTemplateChip' do
    chip_text { "TCT #{Faker::Lorem.word}" }
    description { Faker::Lorem.sentence }
    task_status { TaskStatus.complete.name }
    parent_chip_id { nil }
    learning_outcome_id { 1 }

    comment_text { Faker::Lorem.sentence }
    summary_text { Faker::Lorem.word }
  end
end
