require 'test_helper'

class OneTimeDownloadTicketTest < ActiveSupport::TestCase
  def test_ticket_can_only_be_consumed_once
    Rails.stub(:cache, ActiveSupport::Cache::MemoryStore.new) do
      nonce = OneTimeDownloadTicket.issue!(scope: 'portfolio', expires_in: 30.seconds)

      assert OneTimeDownloadTicket.consume(scope: 'portfolio', nonce: nonce)
      assert_not OneTimeDownloadTicket.consume(scope: 'portfolio', nonce: nonce)
    end
  end

  def test_ticket_is_scoped_to_one_download_kind
    Rails.stub(:cache, ActiveSupport::Cache::MemoryStore.new) do
      nonce = OneTimeDownloadTicket.issue!(scope: 'portfolio', expires_in: 30.seconds)

      assert_not OneTimeDownloadTicket.consume(scope: 'task-submission-files', nonce: nonce)
      assert OneTimeDownloadTicket.consume(scope: 'portfolio', nonce: nonce)
    end
  end

  def test_ticket_expires
    Rails.stub(:cache, ActiveSupport::Cache::MemoryStore.new) do
      travel_to Time.current do
        nonce = OneTimeDownloadTicket.issue!(scope: 'portfolio', expires_in: 30.seconds)

        travel 31.seconds

        assert_not OneTimeDownloadTicket.consume(scope: 'portfolio', nonce: nonce)
      end
    end
  end

end
