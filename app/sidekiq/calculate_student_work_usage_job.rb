# frozen_string_literal: true

require 'open3'

class CalculateStudentWorkUsageJob
  include Sidekiq::Job
  include LogHelper

  # Kept in Sidekiq's Redis so Puma can read it whatever Rails.cache is configured as.
  CACHE_KEY = 'doubtfire:student_work_usage'

  sidekiq_options queue: 'parallel',
                  lock: :until_executed,
                  on_conflict: :reject,
                  retry: false

  def self.cached
    json = Sidekiq.redis { |redis| redis.get(CACHE_KEY) }
    json.present? ? JSON.parse(json) : nil
  rescue StandardError => e
    Rails.logger.warn("Could not read student work usage: #{e.class}: #{e.message}")
    nil
  end

  def perform
    dir = Doubtfire::Application.config.student_work_dir
    started = Time.current

    # du exits non-zero on unreadable entries but still prints a total.
    output, = Open3.capture2('du', '-sk', dir)
    used_kb = output.split.first
    raise "du returned no total for #{dir}" unless used_kb&.match?(/\A\d+\z/)

    result = {
      usedGb: (used_kb.to_f / 1024 / 1024).round(2),
      calculatedAt: Time.current.iso8601,
      durationSeconds: (Time.current - started).round
    }
    Sidekiq.redis { |redis| redis.set(CACHE_KEY, result.to_json) }
    logger.info "Student work usage: #{result[:usedGb]} GB (#{result[:durationSeconds]}s)"
  rescue StandardError => e
    logger.error e
    raise e
  end
end
