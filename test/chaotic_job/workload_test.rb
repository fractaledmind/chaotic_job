# frozen_string_literal: true

require "test_helper"

class ChaoticJob::WorkloadTest < ActiveJob::TestCase
  test "Workload.coerce returns Workloads unchanged" do
    workload = ChaoticJob::BlockWorkload.new(tracing: [Object]) { :noop }
    assert_same workload, ChaoticJob::Workload.coerce(workload)
  end

  test "Workload.coerce wraps an Active Job in a JobWorkload" do
    class CoerceJob < ActiveJob::Base
      def perform
      end
    end

    workload = ChaoticJob::Workload.coerce(CoerceJob.new)
    assert_kind_of ChaoticJob::JobWorkload, workload
    assert_kind_of CoerceJob, workload.job
  end

  test "Workload.coerce rejects anything that is neither" do
    assert_raises(ChaoticJob::Error) { ChaoticJob::Workload.coerce("not a job") }
    assert_raises(ChaoticJob::Error) { ChaoticJob::Workload.coerce(Object.new) }
  end

  test "BlockWorkload requires a non-empty tracing list" do
    assert_raises(ChaoticJob::Error) { ChaoticJob::BlockWorkload.new(tracing: []) { :noop } }
  end

  test "BlockWorkload requires a block" do
    assert_raises(ChaoticJob::Error) { ChaoticJob::BlockWorkload.new(tracing: [Object]) }
  end

  test "BlockWorkload derives a label from the block's source location when none is supplied" do
    workload = ChaoticJob::BlockWorkload.new(tracing: [Object]) { :noop }
    assert_match(/\Ablock@.*\.rb:\d+\z/, workload.identity)
  end

  test "BlockWorkload accepts an explicit label" do
    workload = ChaoticJob::BlockWorkload.new(tracing: [Object], label: "swap-passthrough") { :noop }
    assert_equal "swap-passthrough", workload.identity
  end

  test "JobWorkload installs retry_on for the configured raise_on class on setup" do
    class RetryStampJob < ActiveJob::Base
      def perform
      end
    end

    workload = ChaoticJob::JobWorkload.new(RetryStampJob.new, raise_on: ChaoticJob::RetryableError)
    workload.setup!

    # The handler installed for our retry class is the FIRST one (most recently added).
    handler = RetryStampJob.rescue_handlers.find { |klass, *| Object.const_get(klass) == ChaoticJob::RetryableError }
    refute_nil handler
  end

  test "JobWorkload#clone_for_variant produces an isolated job with cleared exception_executions" do
    class CloneJob < ActiveJob::Base
      def perform
      end
    end

    original = ChaoticJob::JobWorkload.new(CloneJob.new)
    original.job.exception_executions = {"x" => 1}

    cloned = original.clone_for_variant

    refute_same cloned, original
    refute_same cloned.job, original.job
    assert_equal({}, cloned.job.exception_executions)
    assert_equal CloneJob, cloned.job.class
  end
end
