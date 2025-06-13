# frozen_string_literal: true

require "simplecov"
SimpleCov.start do
  enable_coverage :branch
  primary_coverage :branch
  add_filter "/test/"
end

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "chaotic_job"

require "minitest/autorun"
require "active_job"

ActiveJob::Base.logger = Logger.new(ENV["LOG"].present? ? $stdout : IO::NULL)

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

class ActiveSupport::TestCase # rubocop:disable Style/ClassAndModuleChildren
  # Run tests in parallel with specified workers
  parallelize(workers: :number_of_processors)

  # Set default before_setup and after_teardown methods
  def before_setup
    ChaoticJob::Journal.reset!
    performed_jobs.clear if defined?(performed_jobs)
    enqueued_jobs.clear if defined?(enqueued_jobs)
  end

  def after_teardown
  end

  parallelize_setup do |worker|
    SimpleCov.command_name "#{SimpleCov.command_name}-#{worker}"
  end

  parallelize_teardown do |worker|
    SimpleCov.result
  end
end
