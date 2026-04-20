require 'test_helper'

class TaskCompletionSnapshotTest < ActiveSupport::TestCase
  setup do
    @unit = FactoryBot.create(:unit)
    @snapshot = FactoryBot.create(:task_completion_snapshot, unit: @unit)
  end

  test 'task_completion_snapshot belongs to unit' do
    assert @snapshot.unit.is_a?(Unit)
    assert_equal @unit, @snapshot.unit
  end

  test 'task_completion_snapshot is valid with all attributes' do
    assert @snapshot.valid?
  end

  test 'task_completion_snapshot is invalid without snapshot_timestamp' do
    snapshot = FactoryBot.build(:task_completion_snapshot, snapshot_timestamp: nil)
    assert_not snapshot.valid?
    assert snapshot.errors[:snapshot_timestamp].include?("can't be blank")
  end

  test 'task_completion_snapshot enforces unique snapshot_timestamp per unit' do
    duplicate = FactoryBot.build(
      :task_completion_snapshot,
      unit: @unit,
      snapshot_timestamp: @snapshot.snapshot_timestamp
    )

    assert_not duplicate.valid?
    assert duplicate.errors[:snapshot_timestamp].include?('has already been taken')
  end

  test 'task_completion_snapshot allows same snapshot_timestamp for different units' do
    other_unit = FactoryBot.create(:unit)
    snapshot = FactoryBot.build(
      :task_completion_snapshot,
      unit: other_unit,
      snapshot_timestamp: @snapshot.snapshot_timestamp
    )

    assert snapshot.valid?
  end

  test 'store_stats! writes a json file that can be loaded' do
    payload = {
      'Melbourne' => {
        'LA011' => {
          'Task 1' => {
            TaskStatus.complete.id.to_s => 4
          }
        }
      }
    }

    @snapshot.store_stats!(payload)

    assert File.exist?(@snapshot.snapshot_file_path)
    assert_equal payload, @snapshot.load_stats
  end

  test 'load_stats returns empty hash if file missing' do
    snapshot = FactoryBot.create(
      :task_completion_snapshot,
      unit: @unit,
      snapshot_timestamp: (Time.zone.now.to_i + 100).to_s
    )

    FileUtils.rm_f(snapshot.snapshot_file_path)
    assert_equal({}, snapshot.load_stats)
  end

  test 'deleting snapshot deletes associated json file' do
    payload = { 'snapshot' => { 'x' => 1 } }
    @snapshot.store_stats!(payload)

    file_path = @snapshot.snapshot_file_path
    assert File.exist?(file_path)

    @snapshot.destroy
    assert_not File.exist?(file_path)
  end

  test 'snapshot_date is derived from snapshot_timestamp' do
    timestamp = Time.zone.local(2026, 4, 8, 23, 55, 0).to_i.to_s
    snapshot = FactoryBot.build(:task_completion_snapshot, snapshot_timestamp: timestamp)

    assert_equal Date.new(2026, 4, 8), snapshot.snapshot_date
  end
end
