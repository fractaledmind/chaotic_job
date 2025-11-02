# frozen_string_literal: true

require "test_helper"

class ChaoticJob::RaceTest < ActiveJob::TestCase
  test "can run a race with an interleaved callstacks schedule" do
    # prep phase
    job1 = RaceJob1.new
    job2 = RaceJob2.new

    job1_callstack = ChaoticJob::Tracer.new(tracing: RaceJob1).capture do
      job1.enqueue
      ChaoticJob::Performer.perform_all
    end
    job2_callstack = ChaoticJob::Tracer.new(tracing: RaceJob2).capture do
      job2.enqueue
      ChaoticJob::Performer.perform_all
    end

    schedule = job1_callstack.to_a.zip(job2_callstack.to_a).flatten(1)

    race = ChaoticJob::Race.new([job1, job2], schedule: schedule)
    race.run

    assert race.success?
    assert_equal schedule, race.executions
  end
end
