# frozen_string_literal: true

require "test_helper"

class ChaoticJob::SimulationTest < ActiveJob::TestCase
  test "initialize with only job initializes callstack and tracing" do
    simulation = ChaoticJob::Simulation.new(TestJob.new)
    stack = simulation.callstack.to_a

    assert stack.all? { |item| item.is_a?(ChaoticJob::TracedEvent) }
    assert stack.all? { |item| item.owner == TestJob }

    assert_equal :call, stack[0].type
    assert_equal "TestJob#perform", stack[0].key
    assert_equal :line, stack[1].type
    assert_match %r{chaotic_job/test/test_helper.rb:30}, stack[1].key
    assert_equal :line, stack[2].type
    assert_match %r{chaotic_job/test/test_helper.rb:32}, stack[2].key
    assert_equal :return, stack[3].type
    assert_equal "TestJob#perform", stack[3].key

    assert_equal simulation.tracing, [TestJob]
  end

  test "initialize raises error with invalid callstack" do
    assert_raises(ChaoticJob::Error, "callstack must be a generated via ChaoticJob::Tracer") do
      ChaoticJob::Simulation.new(TestJob.new, callstack: [])
    end
  end

  test "initialize with callstack" do
    event = ChaoticJob::TracedEvent.new(TestJob, :call, "#{TestJob.name}#perform")
    callstack = ChaoticJob::Stack.new([event])
    simulation = ChaoticJob::Simulation.new(TestJob.new, callstack: callstack)

    assert_equal simulation.callstack.to_a, [event]
    assert_equal simulation.tracing, [TestJob]
  end

  test "initialize with tracing" do
    tracing = [TestJob, ChaoticJob]
    simulation = ChaoticJob::Simulation.new(TestJob.new, tracing: tracing)
    stack = simulation.callstack.to_a

    assert stack.all? { |item| item.is_a?(ChaoticJob::TracedEvent) }
    assert stack.all? { |item| item.owner == TestJob }

    assert_equal :call, stack[0].type
    assert_equal "TestJob#perform", stack[0].key
    assert_equal :line, stack[1].type
    assert_match %r{chaotic_job/test/test_helper.rb:30}, stack[1].key
    assert_equal :line, stack[2].type
    assert_match %r{chaotic_job/test/test_helper.rb:32}, stack[2].key
    assert_equal :return, stack[3].type
    assert_equal "TestJob#perform", stack[3].key

    assert_equal simulation.tracing, tracing
  end

  test "define creates minitest scenario methods" do
    job = TestJob.new
    event = ChaoticJob::TracedEvent.new(TestJob, :call, "#{TestJob.name}#perform")
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
