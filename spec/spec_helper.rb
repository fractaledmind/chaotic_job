require "bundler/setup"
require "active_job"
require "chaotic_job"

class TestJob < ActiveJob::Base
  def perform(value = :performed, recursions: nil, wait: nil, total: nil)
    ChaoticJob.log_to_journal!(recursions || value)

    if recursions && recursions > 0
      total ||= recursions
      delay = wait ? (wait * (total - recursions + 1)) : 0

      TestJob
        .set(wait: delay)
        .perform_later(value, recursions: recursions - 1, wait: wait, total: total)
    end
  end
end

ActiveJob::Base.queue_adapter = :test
ActiveJob::Base.logger = Logger.new(ENV["LOG"].present? ? $stdout : IO::NULL)
$VERBOSE = ENV["LOG"].present? ? true : nil

RSpec.configure do |config|
  config.include ActiveJob::TestHelper

  config.before(:each) do
    clear_enqueued_jobs
    clear_performed_jobs
    ChaoticJob::Journal.reset! if defined?(ChaoticJob::Journal)
  end

  config.after(:each) do
    clear_enqueued_jobs
    clear_performed_jobs
  end
end
