# frozen_string_literal: true

require "test_helper"

class Job1 < ActiveJob::Base
  def perform
    ChaoticJob.log_to_journal! serialize
    1 + 2
  end
end

class Job2 < ActiveJob::Base
  def perform
    ChaoticJob.log_to_journal! serialize
    step
  end

  def step
    1 + 2
  end
end

class ChaoticJob::RaceTest < ActiveJob::TestCase
  test "can run a race with an interleaved callstacks pattern" do
    # prep phase
    job1 = Job1.new
    job2 = Job2.new

    job1_callstack = ChaoticJob::Tracer.new(tracing: Job1).capture do
      job1.enqueue
      ChaoticJob::Performer.perform_all
    end
    job2_callstack = ChaoticJob::Tracer.new(tracing: Job2).capture do
      job2.enqueue
      ChaoticJob::Performer.perform_all
    end

    pattern = job1_callstack.to_a.zip(job2_callstack.to_a).flatten(1)

    race = ChaoticJob::Race.new([job1, job2], pattern)
    race.run!

    assert race.success?
    assert_equal pattern, race.executions
  end
end
