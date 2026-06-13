# frozen_string_literal: true

require "test_helper"

# These tests exercise Scenario and Simulation over BlockWorkload — the
# point of the Workload abstraction. They prove the same machinery that
# drives Active Jobs drives arbitrary callables, with no Active Job code
# path involved beyond the test framework superclass.
class ChaoticJob::BlockWorkloadIntegrationTest < ActiveJob::TestCase
  # A plain service object — not an Active Job. Mid-execution recovery is
  # the model: if any step raises, a subsequent call should converge.
  class CounterService
    @counter = 0

    class << self
      attr_accessor :counter, :recorded_steps
    end

    def self.reset!
      @counter = 0
      @recorded_steps = []
    end

    def self.call
      step_a
      step_b
      step_c
    end

    def self.step_a
      @counter += 1
      @recorded_steps << :a
    end

    def self.step_b
      @counter += 1
      @recorded_steps << :b
    end

    def self.step_c
      @counter += 1
      @recorded_steps << :c
    end
  end

  def setup
    CounterService.reset!
  end

  test "Scenario runs a BlockWorkload, fires the glitch, and yields control to the user block" do
    glitch = ChaoticJob::Glitch.before_call("#{CounterService.name}.step_b") do
      raise ChaoticJob::RetryableError
    end

    workload = ChaoticJob::BlockWorkload.new(tracing: [CounterService.singleton_class], label: "counter") do
      CounterService.call
    end

    recovery_ran = false
    scenario = ChaoticJob::Scenario.new(workload, glitch: glitch).run do
      # the user's block replaces the workload's drain — we drive recovery
      # ourselves and assert the post-fault state
      assert_raises(ChaoticJob::RetryableError) { workload.drain! }
      recovery_ran = true
    end

    assert scenario.success?, "glitch did not execute"
    assert recovery_ran
    assert_equal [:a], CounterService.recorded_steps # b never recorded; c never reached
    assert_nil scenario.job # not job-shaped; the convenience reader returns nil
    assert_same workload, scenario.workload
  end

  test "Scenario without a user block calls the workload directly (and the glitch's error propagates)" do
    glitch = ChaoticJob::Glitch.before_call("#{CounterService.name}.step_b") do
      raise StandardError, "boom"
    end

    workload = ChaoticJob::BlockWorkload.new(tracing: [CounterService.singleton_class]) do
      CounterService.call
    end

    assert_raises(StandardError, "boom") do
      ChaoticJob::Scenario.new(workload, glitch: glitch, raise: StandardError).run
    end

    # the glitch fired at step_b: step_a ran, step_b raised, step_c never reached
    assert_equal [:a], CounterService.recorded_steps
  end

  test "Simulation traces the BlockWorkload's callstack and runs a scenario per glitch point" do
    test_klass = Class.new(Minitest::Test) do
      include ChaoticJob::Helpers
    end

    workload = ChaoticJob::BlockWorkload.new(tracing: [CounterService.singleton_class]) do
      CounterService.call
    end

    sim = ChaoticJob::Simulation.new(workload, variations: nil, test: test_klass, seed: 1)

    captured_scenarios = []
    sim.define do |scenario|
      captured_scenarios << scenario
      # the assertion the user supplies — recovery is idempotent here, so
      # re-running converges to the full step set
      assert_raises(ChaoticJob::RetryableError) { scenario.workload.drain! }
    end

    # one scenario per traced call/return/line in CounterService.call —
    # at minimum we hit the three step methods on the call event.
    test_methods = test_klass.instance_methods.grep(/\Atest_simulation_scenario_/)
    refute_empty test_methods

    glitched_call_keys = sim.callstack.select { |e| e.type == :call }.map(&:key)
    %w[#{CounterService.name}.step_a #{CounterService.name}.step_b #{CounterService.name}.step_c].each do |k|
      assert_includes glitched_call_keys, k.sub("#\{CounterService.name}", CounterService.name)
    end
  end
end
