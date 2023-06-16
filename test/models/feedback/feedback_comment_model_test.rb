require 'test_helper'

#
# Contains tests for FeedbackComment model objects - not accessed via API
#
class FeedbackCommentModelTest < ActiveSupport::TestCase

    # Setup objects for testing
    def setup
        DatabaseCleaner.start
        criterion = FactoryBot.create(:criterion)
        task_status = TaskStatus.new
        @criterion_option = CriterionOption.create(criterion: criterion, task_status: task_status)

        @task = Task.new
        @user = FactoryBot.create(:user)
        @recipient = FactoryBot.create(:user)
    end

    # Test the creation of a valid feedback comment
    def test_valid_feedback_comment_creation
        feedback_comment = FeedbackComment.new(task: @task, user: @user, recipient: @recipient, comment: 'Test Comment', criterion_option: @criterion_option)
        assert feedback_comment.valid?
    end

    # Test the creation of an invalid feedback comment
    def test_invalid_feedback_comment_creation
        feedback_comment = FeedbackComment.new
        refute feedback_comment.valid?

        feedback_comment.task = @task
        refute feedback_comment.valid?

        feedback_comment.user = @user
        refute feedback_comment.valid?

        feedback_comment.recipient = @recipient
        refute feedback_comment.valid?

        feedback_comment.comment = 'Test Comment'
        refute feedback_comment.valid?

        feedback_comment.criterion_option = @criterion_option
        assert feedback_comment.valid?

        feedback_comment.task = nil
        refute feedback_comment.valid?

        feedback_comment.task = @task
        feedback_comment.user = nil

        refute feedback_comment.save
    end
end
