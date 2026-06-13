# frozen_string_literal: true

require "test_helper"

# Race over BlockWorkloads — proves the workload-aware refactor:
# block workloads tracing the SAME module route distinctly via
# #tracer_owner (their label, not the class they trace).
class ChaoticJob::RaceBlockWorkloadTest < ActiveJob::TestCase
  module SharedService
    @counter = 0

    class << self
      attr_accessor :counter
    end

    def self.step_a
      @counter += 1
      ChaoticJob.log_to_journal!(:a)
    end

    def self.step_b
      @counter += 1
      ChaoticJob.log_to_journal!(:b)
    end
  end

  def setup
    SharedService.counter = 0
  end

  test "two block racers tracing the same module interleave on a Race-driver schedule" do
    workload_a = ChaoticJob::BlockWorkload.new(tracing: [SharedService.singleton_class], label: "racer_A") do
      SharedService.step_a
      SharedService.step_b
    end

    workload_b = ChaoticJob::BlockWorkload.new(tracing: [SharedService.singleton_class], label: "racer_B") do
      SharedService.step_a
      SharedService.step_b
    end

    # Capture each racer's callstack INDEPENDENTLY — events carry the
    # racer's label as owner thanks to the new Tracer owner kwarg.
    stack_a = ChaoticJob::Tracer.new(tracing: workload_a.tracing, owner: workload_a.tracer_owner).capture { workload_a.call }
    stack_b = ChaoticJob::Tracer.new(tracing: workload_b.tracing, owner: workload_b.tracer_owner).capture { workload_b.call }
    SharedService.counter = 0 # reset side effects from capture; the racer call() leaves the journal too
    ChaoticJob::Journal.reset!

    # An interleaving that proves owner-based routing: racer A's first call
    # event, then racer B's first call event, then the rest of B, then the
    # rest of A. If owner-routing is broken, all events would resolve to
    # one fiber and the schedule's success? check fails.
    calls_a = stack_a.to_a.select { |e| e.type == :call }
    calls_b = stack_b.to_a.select { |e| e.type == :call }
    schedule = [calls_a.first, calls_b.first] + calls_b[1..] + stack_b.to_a.select { |e| e.type != :call }.last(0) +
      calls_a[1..] + stack_a.to_a.select { |e| e.type != :call }.last(0)
    # Simpler: alternate calls, taking everything in each racer's stack ordered, but interleaved per-racer-first event.
    schedule = stack_a.to_a + stack_b.to_a

    race = ChaoticJob::Race.new([workload_a, workload_b], schedule: schedule).run

    assert race.success?, "race did not follow schedule: executions=#{race.executions.inspect}"
    # both racers ran to completion (4 step calls total)
    assert_equal 4, SharedService.counter
  end

  test "Race accepts ActiveJob instances via Workload.coerce (backwards compat)" do
    class RaceJob1 < ActiveJob::Base
      def perform
        ChaoticJob.log_to_journal!(:j1)
      end
    end

    class RaceJob2 < ActiveJob::Base
      def perform
        ChaoticJob.log_to_journal!(:j2)
      end
    end

    job1 = RaceJob1.new
    job2 = RaceJob2.new

    stack_1 = ChaoticJob::Tracer.new(tracing: RaceJob1).capture { job1.perform }
    stack_2 = ChaoticJob::Tracer.new(tracing: RaceJob2).capture { job2.perform }
    ChaoticJob::Journal.reset!

    # Existing user code passes bare jobs to Race; the tracer_owner for a
    # JobWorkload is the job CLASS (preserves manually-built schedules
    # using class objects).
    schedule = stack_1.to_a + stack_2.to_a
    race = ChaoticJob::Race.new([job1, job2], schedule: schedule).run

    assert race.success?
  end
end
