# frozen_string_literal: true

require "test_helper"

class ChaoticJob::SimulationTest < ActiveJob::TestCase
  test "initialize with only job initializes callstack and tracing" do
    simulation = ChaoticJob::Simulation.new(TestJob.new)

    assert_equal simulation.callstack.to_a, [
      [:call, "TestJob#perform"],
      [:line, "/Users/fractaled/Code/Gems/chaotic_job/test/test_helper.rb:20"],
      [:line, "/Users/fractaled/Code/Gems/chaotic_job/test/test_helper.rb:22"],
      [:return, "TestJob#perform"]
    ]
    assert_equal simulation.tracing, [TestJob]
  end

  test "initialize raises error with invalid callstack" do
    assert_raises(ChaoticJob::Error, "callstack must be a generated via ChaoticJob::Tracer") do
      ChaoticJob::Simulation.new(TestJob.new, callstack: [])
    end
  end

  test "initialize with callstack" do
    event = [:call, "#{TestJob.name}#perform"]
    callstack = ChaoticJob::Stack.new([event])
    simulation = ChaoticJob::Simulation.new(TestJob.new, callstack:)

    assert_equal simulation.callstack.to_a, [event]
    assert_equal simulation.tracing, [TestJob]
  end

  test "initialize with tracing" do
    tracing = [TestJob, ChaoticJob]
    simulation = ChaoticJob::Simulation.new(TestJob.new, tracing:)

    assert_equal simulation.callstack.to_a, [
      [:call, "TestJob#perform"],
      [:line, "/Users/fractaled/Code/Gems/chaotic_job/test/test_helper.rb:20"],
      [:line, "/Users/fractaled/Code/Gems/chaotic_job/test/test_helper.rb:22"],
      [:return, "TestJob#perform"]
    ]
    assert_equal simulation.tracing, tracing
  end

  test "define creates minitest scenario methods" do
    job = TestJob.new
    event = [:call, "#{TestJob.name}#perform"]
    callstack = ChaoticJob::Stack.new([event])
    test_class = Class.new
    simulation = ChaoticJob::Simulation.new(job, callstack: callstack, test: test_class)

    test_methods = test_class.instance_methods.grep(/^test_simulation_scenario/)
    assert_equal 0, test_methods.size

    simulation.define { nil }

    test_methods = test_class.instance_methods.grep(/^test_simulation_scenario/)
    assert_equal 1, test_methods.size
    assert_equal [:"test_simulation_scenario_before_call_TestJob#perform"], test_methods
  end
end