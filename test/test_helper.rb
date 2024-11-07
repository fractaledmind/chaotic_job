# frozen_string_literal: true

require "simplecov"
SimpleCov.start do
  enable_coverage :branch
  primary_coverage :branch
end

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "chaotic_job"

require "minitest/autorun"
require "active_job"

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
end
