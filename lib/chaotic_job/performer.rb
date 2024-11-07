# frozen_string_literal: true

# Performer.new(Job1).perform_all
# Performer.new(Job1).perform_all_within(time)
# Performer.new(Job1).perform_all_after(time)

module ChaoticJob
  class Performer
    include ActiveJob::TestHelper

    def initialize(job, retry_window: 4)
      @job = job
      @retry_window = retry_window
    end

    def perform_all
      @job.enqueue
      enqueued_jobs_with.sort_by(&:scheduled_at, nil: :first).each do |job|
        perform_job(job)
      end
    end

    def perform_all_after(2.seconds.from_now)
    end

    def perform_all_within(time)
    end

    private

    def perform_enqueued_jobs_only_with_retries
      retry_window = Time.now + @retry_window
      flush_enqueued_jobs(at: retry_window) until enqueued_jobs_with(at: retry_window).empty?
    end

    def perform_any_enqueued_jobs_including_future_scheduled_ones
      flush_enqueued_jobs until enqueued_jobs_with.empty?
    end
  end
end
