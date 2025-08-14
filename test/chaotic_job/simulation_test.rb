# frozen_string_literal: true

require "test_helper"

class ChaoticJob::SimulationTest < ActiveJob::TestCase
  test "initialize with valid parameters" do
    job = TestJob.new
    callstack = ChaoticJob::Stack.new
    callstack << [:call, "#{TestJob.name}#perform"]

    simulation = ChaoticJob::Simulation.new(job, callstack: callstack)

    assert_not_nil simulation
  end

  test "initialize raises error with invalid callstack" do
    job = TestJob.new

    assert_raises(ChaoticJob::Error) do
      ChaoticJob::Simulation.new(job, callstack: [])
    end
  end

  test "scenarios method creates Scenario instances" do
    job = TestJob.new
    callstack = ChaoticJob::Stack.new
    callstack << [:call, "#{TestJob.name}#perform"]

    simulation = ChaoticJob::Simulation.new(job, callstack: callstack, variations: 1)
    scenarios = simulation.send(:scenarios)

    assert_equal 1, scenarios.size
    assert_instance_of ChaoticJob::Scenario, scenarios.first
    assert_equal job.class, scenarios.first.job.class
  end

  test "define creates minitest scenarios without ActiveRecord errors" do
    job = TestJob.new
    callstack = ChaoticJob::Stack.new
    callstack << [:call, "#{TestJob.name}#perform"]

    test_class = Class.new
    simulation = ChaoticJob::Simulation.new(job, callstack: callstack, test: test_class, variations: 1)

    simulation.define do |scenario|
      # Test block
    end

    test_methods = test_class.instance_methods.grep(/^test_simulation_scenario/)
    assert_equal 1, test_methods.size
  end

  test "variants method returns error locations" do
    job = TestJob.new
    callstack = ChaoticJob::Stack.new
    callstack << [:call, "#{TestJob.name}#perform"]
    callstack << [:return, "#{TestJob.name}#perform"]

    simulation = ChaoticJob::Simulation.new(job, callstack: callstack)
    variants = simulation.send(:variants)

    assert_equal 2, variants.size
    assert_includes variants, ["before_call", "#{TestJob.name}#perform"]
    assert_includes variants, ["before_return", "#{TestJob.name}#perform"]
  end

  test "clone_job_template creates independent job copy" do
    job = TestJob.new
    job.job_id = "test-job-123"
    callstack = ChaoticJob::Stack.new
    callstack << [:call, "#{TestJob.name}#perform"]

    simulation = ChaoticJob::Simulation.new(job, callstack: callstack)
    cloned_job = simulation.send(:clone_job_template)

    assert_equal job.class, cloned_job.class
    refute_equal job.object_id, cloned_job.object_id
    assert_empty cloned_job.exception_executions
  end
end
