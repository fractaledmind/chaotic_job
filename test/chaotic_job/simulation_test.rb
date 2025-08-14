# frozen_string_literal: true

require "test_helper"

class ChaoticJob::SimulationTest < ActiveJob::TestCase
  test "initialize with only job initializes callstack and tracing" do
    simulation = ChaoticJob::Simulation.new(TestJob.new)

    stack = simulation.callstack.to_a
    assert_equal stack[0], [:call, "TestJob#perform"]
    assert_equal stack[1][0], :line
    assert_match %r{chaotic_job/test/test_helper.rb:30}, stack[1][1]
    assert_equal stack[2][0], :line
    assert_match %r{chaotic_job/test/test_helper.rb:32}, stack[2][1]
    assert_equal stack[3], [:return, "TestJob#perform"]

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
    simulation = ChaoticJob::Simulation.new(TestJob.new, callstack: callstack)

    assert_equal simulation.callstack.to_a, [event]
    assert_equal simulation.tracing, [TestJob]
  end

  test "initialize with tracing" do
    tracing = [TestJob, ChaoticJob]
    simulation = ChaoticJob::Simulation.new(TestJob.new, tracing: tracing)

    stack = simulation.callstack.to_a
    assert_equal stack[0], [:call, "TestJob#perform"]
    assert_equal stack[1][0], :line
    assert_match %r{chaotic_job/test/test_helper.rb:30}, stack[1][1]
    assert_equal stack[2][0], :line
    assert_match %r{chaotic_job/test/test_helper.rb:32}, stack[2][1]
    assert_equal stack[3], [:return, "TestJob#perform"]

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
