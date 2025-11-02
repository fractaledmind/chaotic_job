# frozen_string_literal: true

require "test_helper"

class ChaoticJob::RelayTest < ActiveJob::TestCase
  test "can run a relay with all possible races for passed jobs" do
    job1 = RaceJob1.new
    job2 = RaceJob2.new
    test_class = Class.new
    relay = ChaoticJob::Relay.new(job1, job2, test: test_class)

    test_methods = test_class.instance_methods.grep(/^test_race_schedule/)
    assert_equal 0, test_methods.size

    relay.define { nil }

    test_methods = test_class.instance_methods.grep(/^test_race_schedule/)
    assert_equal relay.sample, test_methods.size
  end
end
