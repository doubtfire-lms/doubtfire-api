require 'test_helper'

class TaskCompletionSnapshotTest < ActiveSupport::TestCase
  setup do
    @unit = FactoryBot.create(:unit)
    @snapshot = FactoryBot.create(:task_completion_snapshot, unit: @unit)
  end

  # Association tests
  test 'task_completion_snapshot belongs to unit' do
    assert @snapshot.unit.is_a?(Unit)
    assert_equal @unit, @snapshot.unit
  end

  # Presence validation tests
  test 'task_completion_snapshot is valid with all attributes' do
    assert @snapshot.valid?
  end

  test 'task_completion_snapshot is invalid without snapshot_date' do
    snapshot = FactoryBot.build(:task_completion_snapshot, snapshot_date: nil)
    assert_not snapshot.valid?
    assert snapshot.errors[:snapshot_date].include?("can't be blank")
  end

  test 'task_completion_snapshot is invalid without captured_at' do
    snapshot = FactoryBot.build(:task_completion_snapshot, captured_at: nil)
    assert_not snapshot.valid?
    assert snapshot.errors[:captured_at].include?("can't be blank")
  end

  test 'task_completion_snapshot is invalid without stats' do
    snapshot = FactoryBot.build(:task_completion_snapshot, stats: nil)
    assert_not snapshot.valid?
    assert snapshot.errors[:stats].include?("can't be blank")
  end

  test 'task_completion_snapshot is invalid with empty stats hash' do
    snapshot = FactoryBot.build(:task_completion_snapshot, stats: {})
    assert_not snapshot.valid?
    assert snapshot.errors[:stats].include?("can't be blank")
  end

  # Uniqueness validation tests
  test 'task_completion_snapshot enforces unique snapshot_date per unit' do
    duplicate = FactoryBot.build(:task_completion_snapshot,
                                  unit: @unit,
                                  snapshot_date: @snapshot.snapshot_date)
    assert_not duplicate.valid?
    assert duplicate.errors[:snapshot_date].include?('has already been taken')
  end

  test 'task_completion_snapshot allows same snapshot_date for different units' do
    other_unit = FactoryBot.create(:unit)
    snapshot = FactoryBot.build(:task_completion_snapshot,
                                unit: other_unit,
                                snapshot_date: @snapshot.snapshot_date)
    assert snapshot.valid?
  end

  # Creation tests
  test 'can create task_completion_snapshot with valid attributes' do
    snapshot = FactoryBot.create(:task_completion_snapshot)
    assert snapshot.persisted?
    assert_not_nil snapshot.id
  end

  test 'snapshot_date is stored correctly' do
    date = Date.current - 5.days
    snapshot = FactoryBot.create(:task_completion_snapshot, snapshot_date: date)
    assert_equal date, snapshot.snapshot_date
  end

  test 'captured_at is stored correctly' do
    time = Time.zone.now - 2.hours
    snapshot = FactoryBot.create(:task_completion_snapshot, captured_at: time)
    assert_equal time.to_i, snapshot.captured_at.to_i
  end

  test 'stats json is stored and retrieved correctly' do
    stats_data = {
      'completed' => 10,
      'in_progress' => 7,
      'not_started' => 3,
      'not_required' => 5
    }
    snapshot = FactoryBot.create(:task_completion_snapshot, stats: stats_data)
    assert_equal stats_data, snapshot.stats
  end

  # Querying tests
  test 'can find snapshot by unit and snapshot_date' do
    found = TaskCompletionSnapshot.find_by(unit: @unit, snapshot_date: @snapshot.snapshot_date)
    assert_equal @snapshot, found
  end

  test 'can query all snapshots for a unit' do
    other_snapshot = FactoryBot.create(:task_completion_snapshot,
                                       unit: @unit,
                                       snapshot_date: Time.zone.today + 1.day)
    snapshots = @unit.task_completion_snapshots
    assert_includes snapshots, @snapshot
    assert_includes snapshots, other_snapshot
    assert_equal 2, snapshots.count
  end

  # Deletion tests
  test 'can delete task_completion_snapshot' do
    snapshot = FactoryBot.create(:task_completion_snapshot, snapshot_date: Date.current + 10.days)
    id = snapshot.id
    snapshot.destroy
    assert_nil TaskCompletionSnapshot.find_by(id: id)
  end

  test 'deleting snapshot does not affect unit' do
    snapshot = FactoryBot.create(:task_completion_snapshot, unit: @unit, snapshot_date: Date.current + 5.days)
    snapshot.destroy
    assert_not_nil Unit.find(@unit.id)
  end
end
