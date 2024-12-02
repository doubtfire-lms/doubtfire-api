FactoryBot.define do
  factory :feedback_group_chip, class: 'Feedback::FeedbackGroupChip' do
    chip_text { "Sample title" }
    description { "Sample description" }
    parent_chip_id { nil }
    learning_outcome_id { 1 }
  end

  factory :feedback_template_chip, class: 'Feedback::FeedbackTemplateChip' do
    chip_text { "Sample chip text" }
    description { "Sample description" }
    task_status { "In Progress" }
    parent_chip_id { nil }
    learning_outcome_id { 1 }

    comment_text { "Sample comment text" }
    summary_text { "Sample summary text" }
  end
end
