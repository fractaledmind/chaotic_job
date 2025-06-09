# frozen_string_literal: true

require "test_helper"

class ChaoticJob::PerformerTest < ActiveJob::TestCase
  test "perform_all executes all enqueued jobs" do
    TestJob.perform_later(:job1)
    TestJob.perform_later(:job2)

    assert_equal 2, enqueued_jobs.size
    assert_equal 0, performed_jobs.size

    ChaoticJob::Performer.perform_all

    assert_equal 0, enqueued_jobs.size
    assert_equal 2, performed_jobs.size
    assert_equal [:job1, :job2], ChaoticJob.journal_entries
  end

  test "perform_all handles empty queue" do
    assert_equal 0, enqueued_jobs.size

    ChaoticJob::Performer.perform_all

    assert_equal 0, enqueued_jobs.size
    assert_equal 0, performed_jobs.size
  end

  test "perform_all_before with Time cutoff executes jobs scheduled to run before the cutoff" do
    now = Time.current

    TestJob.set(wait_until: now - 1.hour).perform_later(:past)
    TestJob.set(wait_until: now + 30.minutes).perform_later(:near_future)
    TestJob.set(wait_until: now + 2.hours).perform_later(:far_future)
    TestJob.perform_later(:immediate)

    ChaoticJob::Performer.perform_all_before(now + 1.hour)

    assert_equal 1, enqueued_jobs.size  # far_future job remains
    assert_equal 3, performed_jobs.size
    assert_equal [:immediate, :past, :near_future], ChaoticJob.journal_entries
  end

  test "perform_all_within with Duration cutoff executes jobs scheduled to run before the cutoff" do
    now = Time.current

    TestJob.set(wait_until: now - 1.hour).perform_later(:past)
    TestJob.set(wait_until: now + 30.minutes).perform_later(:near_future)
    TestJob.set(wait_until: now + 2.hours).perform_later(:far_future)
    TestJob.perform_later(:immediate)

    ChaoticJob::Performer.perform_all_within(1.hour)

    assert_equal 1, enqueued_jobs.size  # far_future job remains
    assert_equal 3, performed_jobs.size
    assert_equal [:immediate, :past, :near_future], ChaoticJob.journal_entries
  end

  test "perform_all_after with Time cutoff executes jobs scheduled to run after the cutoff" do
    now = Time.current

    TestJob.set(wait_until: now - 1.hour).perform_later(:past)
    TestJob.set(wait_until: now + 30.minutes).perform_later(:near_future)
    TestJob.set(wait_until: now + 2.hours).perform_later(:far_future)
    TestJob.perform_later(:immediate)

    ChaoticJob::Performer.perform_all_after(now + 1.hour)

    assert_equal 2, enqueued_jobs.size  # past and near_future remain
    assert_equal 2, performed_jobs.size
    assert_equal [:immediate, :far_future], ChaoticJob.journal_entries
  end

  test "perform_all_after with Duration cutoff executes jobs scheduled to run after the cutoff" do
    now = Time.current

    TestJob.set(wait_until: now - 1.hour).perform_later(:past)
    TestJob.set(wait_until: now + 30.minutes).perform_later(:near_future)
    TestJob.set(wait_until: now + 2.hours).perform_later(:far_future)
    TestJob.perform_later(:immediate)

    ChaoticJob::Performer.perform_all_after(1.hour)

    assert_equal 2, enqueued_jobs.size  # past and near_future remain
    assert_equal 2, performed_jobs.size
    assert_equal [:immediate, :far_future], ChaoticJob.journal_entries
  end

  test "perform with specific jobs" do
    TestJob.perform_later(:job1)
    TestJob.perform_later(:job2)

    jobs_to_perform = enqueued_jobs.first(1)
    result = ChaoticJob::Performer.perform(jobs_to_perform)

    assert_equal 1, result
    assert_equal 1, enqueued_jobs.size
    assert_equal 1, performed_jobs.size
    assert_equal [:job1], ChaoticJob.journal_entries
  end

  test "perform with empty array" do
    result = ChaoticJob::Performer.perform([])

    assert_equal 0, result
    assert_equal 0, performed_jobs.size
  end

  test "resolve_cutoff rounds to nearest second for second-level difference in future" do
    now = Time.now
    delta = 30.seconds
    target = now + delta
    result = ChaoticJob::Performer.resolve_cutoff(target)

    assert_equal 0, result.usec
    assert_equal target.sec, result.sec
    assert_equal target.min, result.min
    assert_equal target.hour, result.hour
    assert_equal target.day, result.day
    assert_equal target.year, result.year
  end

  test "resolve_cutoff rounds to nearest minute for minute-level difference in future" do
    now = Time.now
    delta = 30.minutes
    target = now + delta
    result = ChaoticJob::Performer.resolve_cutoff(target)

    assert_equal 0, result.usec
    assert_equal 0, result.sec
    assert_equal target.min, result.min
    assert_equal target.hour, result.hour
    assert_equal target.day, result.day
    assert_equal target.year, result.year
  end

  test "resolve_cutoff rounds to nearest hour for hour-level difference in future" do
    now = Time.now
    delta = 3.hours
    target = now + delta
    result = ChaoticJob::Performer.resolve_cutoff(target)

    assert_equal 0, result.usec
    assert_equal 0, result.sec
    assert_equal 0, result.min
    assert_equal target.hour, result.hour
    assert_equal target.day, result.day
    assert_equal target.year, result.year
  end

  test "resolve_cutoff rounds to nearest day for day-level difference in future" do
    now = Time.now
    delta = 3.days
    target = now + delta
    result = ChaoticJob::Performer.resolve_cutoff(target)

    assert_equal 0, result.usec
    assert_equal 0, result.sec
    assert_equal 0, result.min
    assert_equal 0, result.hour
    assert_equal target.day, result.day
    assert_equal target.year, result.year
  end

  test "resolve_cutoff rounds to nearest second for second-level difference in past" do
    now = Time.now
    delta = 30.seconds
    target = now - delta
    result = ChaoticJob::Performer.resolve_cutoff(target)

    assert_equal 0, result.usec
    assert_equal target.sec, result.sec
    assert_equal target.min, result.min
    assert_equal target.hour, result.hour
    assert_equal target.day, result.day
    assert_equal target.year, result.year
  end

  test "resolve_cutoff rounds to nearest minute for minute-level difference in past" do
    now = Time.now
    delta = 30.minutes
    target = now - delta
    result = ChaoticJob::Performer.resolve_cutoff(target)

    assert_equal 0, result.usec
    assert_equal 0, result.sec
    assert_equal target.min, result.min
    assert_equal target.hour, result.hour
    assert_equal target.day, result.day
    assert_equal target.year, result.year
  end

  test "resolve_cutoff rounds to nearest hour for hour-level difference in past" do
    now = Time.now
    delta = 3.hours
    target = now - delta
    result = ChaoticJob::Performer.resolve_cutoff(target)

    assert_equal 0, result.usec
    assert_equal 0, result.sec
    assert_equal 0, result.min
    assert_equal target.hour, result.hour
    assert_equal target.day, result.day
    assert_equal target.year, result.year
  end

  test "resolve_cutoff rounds to nearest day for day-level difference in past" do
    now = Time.now
    delta = 3.days
    target = now - delta
    result = ChaoticJob::Performer.resolve_cutoff(target)

    assert_equal 0, result.usec
    assert_equal 0, result.sec
    assert_equal 0, result.min
    assert_equal 0, result.hour
    assert_equal target.day, result.day
    assert_equal target.year, result.year
  end

  test "resolve_cutoff with invalid input" do
    assert_raises(ChaoticJob::Error) do
      ChaoticJob::Performer.resolve_cutoff(DateTime.now)
    end
  end

  test "perform_all executes jobs that enqueue more jobs until no jobs are left" do
    TestJob.perform_later(recursions: 2)
    ChaoticJob::Performer.perform_all

    assert_equal 0, enqueued_jobs.size
    assert_equal 3, performed_jobs.size
    assert_equal [2, 1, 0], ChaoticJob.journal_entries
  end

  test "perform_all_before executes jobs that enqueue more jobs until no jobs are left scheduled to run before the cutoff" do
    TestJob.perform_later(recursions: 4, wait: 30.minutes)
    ChaoticJob::Performer.perform_all_before(1.hour)

    assert_equal 1, enqueued_jobs.size
    assert_equal 2, performed_jobs.size
    assert_equal [4, 3], ChaoticJob.journal_entries
  end

  test "perform_all_after executes jobs that enqueue more jobs until no jobs are left scheduled to run after the cutoff" do
    TestJob.perform_later(recursions: 4, wait: 30.minutes)
    ChaoticJob::Performer.perform_all_after(1.hour)

    assert_equal 1, enqueued_jobs.size
    assert_equal 1, performed_jobs.size
    assert_equal [4], ChaoticJob.journal_entries
  end
end
