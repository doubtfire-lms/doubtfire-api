require "test_helper"

class TaskSimilarityTest < ActiveSupport::TestCase

  # Test that when you create a plagiarism match link, that a moss test needs the other task
  def test_other_details
    task = FactoryBot.create(:task)

    similarity = MossTaskSimilarity.create(
      task: task,
      pct: 10
    )

    refute similarity.valid?, similarity.errors.full_messages

    similarity.other_task = task
    assert similarity.valid?, similarity.errors.full_messages

    tii_similarity = TiiTaskSimilarity.create!(
      task: task,
      pct: 10,
      tii_submission: TiiSubmission.create!(
        task: task,
        idx: 0,
        filename: 'test.doc',
        status: :created,
        submitted_by_user: task.unit.main_convenor_user
      )
    )

    assert tii_similarity.valid?, tii_similarity.errors.full_messages

  ensure
    task&.project&.unit&.destroy
  end

  # Test to ensure that pct must be between 0 and 100
  def test_similarity_pct
    task = FactoryBot.create(:task)

    similarity = MossTaskSimilarity.create(
      task: task,
      other_task: task,
      pct: 10
    )

    assert similarity.valid?, similarity.errors.full_messages

    similarity.pct = -1
    refute similarity.valid?
    similarity.pct = 101
    refute similarity.valid?

    similarity.pct = 0
    assert similarity.valid?, similarity.errors.full_messages
    similarity.pct = 100
    assert similarity.valid?, similarity.errors.full_messages
  ensure
    task&.project&.unit&.destroy
  end

  # Test ability to access similarity data from task
  def test_similarity_from_task
    task = FactoryBot.create(:task)

    MossTaskSimilarity.create(
      task: task,
      other_task: task,
      pct: 10,
      flagged: true
    )

    MossTaskSimilarity.create(
      task: task,
      other_task: task,
      pct: 5
    )

    TiiTaskSimilarity.create(
      task: task,
      pct: 10,
      flagged: true,
      tii_submission: TiiSubmission.create!(
        task: task,
        idx: 0,
        filename: 'test.doc',
        status: :created,
        submitted_by_user: task.unit.main_convenor_user
      )
    )

    TiiTaskSimilarity.create(
      task: task,
      pct: 20,
      tii_submission: TiiSubmission.create!(
        task: task,
        idx: 1,
        filename: 'test.doc',
        status: :created,
        submitted_by_user: task.unit.main_convenor_user
      )
    )

    assert_equal 4, task.task_similarities.count

    assert_equal 2, task.task_similarities.where(flagged: true).count
  ensure
    task&.project&.unit&.destroy
  end
end
