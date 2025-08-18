# frozen_string_literal: true

require "test_helper"

class ChaoticJob::ScenarioTest < ActiveJob::TestCase
  test "default parameters and blockless #run retries job" do
    scenario = ChaoticJob::Scenario.new(
      TestJob.new,
      glitch: ChaoticJob::Glitch.before_call("#{TestJob.name}#perform")
    )
    scenario.run

    assert_equal(
      [
        "enqueue.active_job",
        "perform_start.active_job",
        "enqueue_at.active_job",
        "enqueue_retry.active_job",
        "perform.active_job",
        "perform_start.active_job",
        "perform.active_job"
      ],
      scenario.events.map(&:name)
    )
    assert_equal [:performed], ChaoticJob.journal_entries
  end

  test "custom raise parameter and blockless #run does not retry job" do
    scenario = ChaoticJob::Scenario.new(
      TestJob.new,
      glitch: ChaoticJob::Glitch.before_call("#{TestJob.name}#perform"),
      raise: StandardError
    )
    assert_raise(StandardError) do
      scenario.run
    end

    assert_equal(
      [
        "enqueue.active_job",
        "perform_start.active_job",
        "perform.active_job"
      ],
      scenario.events.map(&:name)
    )
    assert_nil ChaoticJob.journal_entries
  end

  test "custom capture parameter and blockless #run retries job and only captures matching events" do
    scenario = ChaoticJob::Scenario.new(
      TestJob.new,
      glitch: ChaoticJob::Glitch.before_call("#{TestJob.name}#perform"),
      capture: /perform/
    )
    scenario.run

    assert_equal(
      [
        "perform_start.active_job",
        "perform.active_job",
        "perform_start.active_job",
        "perform.active_job"
      ],
      scenario.events.map(&:name)
    )
    assert_equal [:performed], ChaoticJob.journal_entries
  end

  test "invalid glitch parameter raises" do
    assert_raises(ChaoticJob::Error) do
      ChaoticJob::Scenario.new(
        TestJob.new,
        glitch: [:before_call, "#{TestJob.name}#perform"]
      )
    end
  end

  test "default parameters and #run with block executes the block but does not perform job" do
    scenario = ChaoticJob::Scenario.new(
      TestJob.new,
      glitch: ChaoticJob::Glitch.before_call("#{TestJob.name}#perform")
    )
    block_executed = false

    scenario.run do
      block_executed = true
    end

    assert block_executed
    assert_equal(
      [
        "enqueue.active_job"
      ],
      scenario.events.map(&:name)
    )
    assert_nil ChaoticJob.journal_entries
  end

  test "success? returns false when glitch not executed" do
    scenario = ChaoticJob::Scenario.new(
      TestJob.new,
      glitch: ChaoticJob::Glitch.before_call("NonExistentClass#nonexistent_method")
    )
    scenario.run

    assert_equal false, scenario.success?
    assert_equal(
      [
        "enqueue.active_job",
        "perform_start.active_job",
        "perform.active_job"
      ],
      scenario.events.map(&:name)
    )
    assert_equal [:performed], ChaoticJob.journal_entries
  end

  test "success? returns true when glitch is executed" do
    scenario = ChaoticJob::Scenario.new(
      TestJob.new,
      glitch: ChaoticJob::Glitch.before_call("#{TestJob.name}#perform")
    )
    scenario.run

    assert_equal true, scenario.success?
    assert_equal(
      [
        "enqueue.active_job",
        "perform_start.active_job",
        "enqueue_at.active_job",
        "enqueue_retry.active_job",
        "perform.active_job",
        "perform_start.active_job",
        "perform.active_job"
      ],
      scenario.events.map(&:name)
    )
    assert_equal [:performed], ChaoticJob.journal_entries
  end

  test "run handles job that schedules other jobs" do
    class ParentJob < ActiveJob::Base
      def perform
        ChaoticJob.log_to_journal!(:parent_start)
        ChildJob.perform_later
        ChaoticJob.log_to_journal!(:parent_end)
      end
    end

    class ChildJob < ActiveJob::Base
      def perform
        ChaoticJob.log_to_journal!(:child)
      end
    end

    scenario = ChaoticJob::Scenario.new(
      ParentJob.new,
      glitch: ChaoticJob::Glitch.before_call("#{ParentJob.name}#perform")
    )
    scenario.run

    assert_equal(
      [
        "enqueue.active_job",
        "perform_start.active_job",
        "enqueue_at.active_job",
        "enqueue_retry.active_job",
        "perform.active_job",
        "perform_start.active_job",
        "enqueue.active_job",
        "perform.active_job",
        "perform_start.active_job",
        "perform.active_job"
      ],
      scenario.events.map(&:name)
    )
    assert_equal [:parent_start, :parent_end, :child], ChaoticJob.journal_entries
  end

  test "before_line? returns true when glitch matches" do
    key = "#{__FILE__}:181"
    scenario = ChaoticJob::Scenario.new(
      TestJob.new,
      glitch: ChaoticJob::Glitch.before_line(key)
    )

    assert scenario.before_line? key
  end

  test "before_line? returns false when glitch does not match key" do
    key = "#{__FILE__}:191"
    scenario = ChaoticJob::Scenario.new(
      TestJob.new,
      glitch: ChaoticJob::Glitch.before_line(key)
    )

    refute scenario.before_line? "#{__FILE__}:000"
  end

  test "before_line? returns false when glitch does not match event" do
    key = "#{__FILE__}:191"
    scenario = ChaoticJob::Scenario.new(
      TestJob.new,
      glitch: ChaoticJob::Glitch.before_call(key)
    )

    refute scenario.before_line? key
  end

  test "before_call? returns true when glitch matches" do
    key = "#{TestJob.name}#perform"
    scenario = ChaoticJob::Scenario.new(
      TestJob.new,
      glitch: ChaoticJob::Glitch.before_call(key)
    )

    assert scenario.before_call? key
  end

  test "before_call? returns false when glitch does not match key" do
    key = "#{TestJob.name}#perform"
    scenario = ChaoticJob::Scenario.new(
      TestJob.new,
      glitch: ChaoticJob::Glitch.before_call(key)
    )

    refute scenario.before_call? "SomeJob#perform"
  end

  test "before_call? returns false when glitch does not match event" do
    key = "#{__FILE__}:191"
    scenario = ChaoticJob::Scenario.new(
      TestJob.new,
      glitch: ChaoticJob::Glitch.before_return(key)
    )

    refute scenario.before_call? key
  end

  test "before_return? returns true when glitch matches" do
    key = "#{TestJob.name}#perform"
    scenario = ChaoticJob::Scenario.new(
      TestJob.new,
      glitch: ChaoticJob::Glitch.before_return(key)
    )

    assert scenario.before_return? key
  end

  test "before_return? returns false when glitch does not match key" do
    key = "#{TestJob.name}#perform"
    scenario = ChaoticJob::Scenario.new(
      TestJob.new,
      glitch: ChaoticJob::Glitch.before_return(key)
    )

    refute scenario.before_return? "SomeJob#perform"
  end

  test "before_return? returns false when glitch does not match event" do
    key = "#{__FILE__}:191"
    scenario = ChaoticJob::Scenario.new(
      TestJob.new,
      glitch: ChaoticJob::Glitch.before_line(key)
    )

    refute scenario.before_return? key
  end
end
