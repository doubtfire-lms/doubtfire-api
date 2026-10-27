require 'test_helper'
require 'tmpdir'
require 'set'

class PortfolioEvidenceTest < ActiveSupport::TestCase
  def test_pdf_generator_leaves_sidekiq_jobs_and_claims_other_stale_submissions
    Dir.mktmpdir do |root|
      new_root = File.join(root, 'new')
      FileUtils.mkdir_p([File.join(new_root, '123'), File.join(new_root, '456'), File.join(root, 'in_process')])

      PortfolioEvidence.stub(:student_work_dir, ->(type) { File.join(root, type.to_s) }) do
        PortfolioEvidence.stub(:sidekiq_owned_submission_ids, Set.new([123])) do
          File.stub(:ctime, 31.minutes.ago) do
            claimed_folder = PortfolioEvidence.move_to_pid_folder

            assert File.directory?(File.join(new_root, '123'))
            assert File.directory?(File.join(claimed_folder, '456'))
            assert_not File.exist?(File.join(new_root, '456'))
          end
        end
      end
    end
  end

  def test_queued_jobs_only_block_pdf_generator_while_default_queue_is_running
    running = [[nil, nil, { 'payload' => { 'class' => 'AcceptSubmissionJob', 'args' => [123] } }]]
    queued = Struct.new(:klass, :args).new('AcceptSubmissionJob', [456])
    process = Struct.new(:queues, :stopping) do
      def stopping?
        stopping
      end
    end.new(['default'], false)

    Sidekiq::Workers.stub(:new, running) do
      Sidekiq::Queue.stub(:new, [queued]) do
        Sidekiq::ProcessSet.stub(:new, [process]) do
          assert_equal Set.new([123, 456]), PortfolioEvidence.sidekiq_owned_submission_ids
        end

        Sidekiq::ProcessSet.stub(:new, []) do
          assert_equal Set.new([123]), PortfolioEvidence.sidekiq_owned_submission_ids
        end

        process.stopping = true
        Sidekiq::ProcessSet.stub(:new, [process]) do
          assert_equal Set.new([123]), PortfolioEvidence.sidekiq_owned_submission_ids
        end
      end
    end
  end

  def test_pdf_generator_can_fall_back_when_redis_is_unavailable
    Sidekiq::Workers.stub(:new, -> { raise IOError, 'Redis unavailable' }) do
      assert_equal Set.new, PortfolioEvidence.sidekiq_owned_submission_ids
    end
  end
end
