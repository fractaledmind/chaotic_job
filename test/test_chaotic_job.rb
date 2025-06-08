# frozen_string_literal: true

require "test_helper"

class TestChaoticJob < ActiveJob::TestCase
  include ChaoticJob::Helpers

  test "performing a simple job" do
    class Job1 < ActiveJob::Base
      def perform
        step_1
        step_2
      end

      def step_1
        ChaoticJob.log_to_journal!
      end

      def step_2
        ChaoticJob.log_to_journal!
      end
    end

    Job1.perform_later
    perform_all_jobs

    assert_equal 2, ChaoticJob.journal_size
  end

  test "performing a job that schedules another job" do
    class Job2 < ActiveJob::Base
      class ChildJob < ActiveJob::Base
        def perform
          ChaoticJob.log_to_journal!(scope: :child)
        end
      end

      retry_on StandardError

      def perform
        step_1
        step_2
        step_3
      end

      def step_1
        ChaoticJob.log_to_journal!(scope: :parent)
      end

      def step_2
        ChildJob.set(wait: 1.week).perform_later
      end

      def step_3
        raise StandardError if executions == 1
        ChaoticJob.log_to_journal!(scope: :parent)
      end
    end

    Job2.perform_later
    perform_all_jobs_within(4.seconds)

    assert_equal 2, enqueued_jobs.size
    assert_equal 2, performed_jobs.size
    assert_equal 3, ChaoticJob.journal_size(scope: :parent)
    assert_equal 0, ChaoticJob.journal_size(scope: :child)

    perform_all_jobs_after(7.days)

    assert_equal 0, enqueued_jobs.size
    assert_equal 4, performed_jobs.size
    assert_equal 3, ChaoticJob.journal_size(scope: :parent)
    assert_equal 2, ChaoticJob.journal_size(scope: :child)
  end

  test "scenario of a simple job" do
    class Job3 < ActiveJob::Base
      def perform
        step_1
        step_2
        step_3
      end

      def step_1
        ChaoticJob.log_to_journal!(:step_1)
      end

      def step_2
        ChaoticJob.log_to_journal!(:step_2)
      end

      def step_3
        ChaoticJob.log_to_journal!(:step_3)
      end
    end

    run_scenario(Job3.new, glitch: ChaoticJob::Glitch.before_call("#{Job3.name}#step_3"))

    assert_equal 5, ChaoticJob.journal_size
    assert_equal [:step_1, :step_2, :step_1, :step_2, :step_3], ChaoticJob.journal_entries
  end

  test "scenario with glitch argument" do
    class Job4 < ActiveJob::Base
      def perform
        step(1)
        step(2)
        step(3)
      end

      def step(argument)
        ChaoticJob.log_to_journal!(argument)
      end
    end

    run_scenario(Job4.new, glitch: ChaoticJob::Glitch.before_call("#{Job4.name}#step", 2))

    assert_equal 4, ChaoticJob.journal_size
    assert_equal [1, 1, 2, 3], ChaoticJob.journal_entries
  end

  test "scenario with glitch keyword argument" do
    class Job5 < ActiveJob::Base
      def perform
        step(keyword: 1)
        step(keyword: 2)
        step(keyword: 3)
      end

      def step(keyword:)
        ChaoticJob.log_to_journal!(keyword)
      end
    end

    run_scenario(Job5.new, glitch: ChaoticJob::Glitch.before_call("#{Job5.name}#step", keyword: 2))

    assert_equal 4, ChaoticJob.journal_size
    assert_equal [1, 1, 2, 3], ChaoticJob.journal_entries
  end

  test "scenario with glitch keyword and positional argument" do
    class Job6 < ActiveJob::Base
      def perform
        step(1, keyword: "1")
        step(2, keyword: "2")
        step(3, keyword: "3")
      end

      def step(*positional)
        ChaoticJob.log_to_journal!(positional)
      end
    end

    glitch = ChaoticJob::Glitch.new.before_call("#{Job6.name}#step", 2, {keyword: "2"})
    run_scenario(Job6.new, glitch: glitch)

    assert_equal 4, ChaoticJob.journal_size
    assert_equal [[1, {keyword: "1"}], [1, {keyword: "1"}], [2, {keyword: "2"}], [3, {keyword: "3"}]], ChaoticJob.journal_entries
  end

  test "simulation of a simple job" do
    class Job7 < ActiveJob::Base
      def perform
        step_1
        step_2
        step_3
      end

      def step_1
        ChaoticJob.log_to_journal!
      end

      def step_2
        ChaoticJob.log_to_journal!
      end

      def step_3
        ChaoticJob.log_to_journal!
      end
    end

    assert true
    run_simulation(Job7.new) do |scenario|
      assert_operator ChaoticJob.journal_size, :>=, 3
    end
  end
end
