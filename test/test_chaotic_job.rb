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
    perform_all

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
    perform_all_within(4.seconds)

    assert_equal 2, enqueued_jobs.size
    assert_equal 2, performed_jobs.size
    assert_equal 3, ChaoticJob.journal_size(scope: :parent)
    assert_equal 0, ChaoticJob.journal_size(scope: :child)

    perform_all_after(7.days)

    assert_equal 0, enqueued_jobs.size
    assert_equal 4, performed_jobs.size
    assert_equal 3, ChaoticJob.journal_size(scope: :parent)
    assert_equal 2, ChaoticJob.journal_size(scope: :child)
  end

  test "simulation of a simple job" do
    class Job3 < ActiveJob::Base
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
    run_simulation(Job3.new) do |scenario|
      assert_operator ChaoticJob.journal_size, :>=, 3
    end
  end

  test "scenario of a simple job" do
    class Job4 < ActiveJob::Base
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

    run_scenario(Job4.new, glitch: ["before", "#{__FILE__}:108"])

    assert_equal 5, ChaoticJob.journal_size
  end
end
