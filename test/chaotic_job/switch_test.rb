# frozen_string_literal: true

require "test_helper"

class ChaoticJob::SwitchTest < ActiveJob::TestCase
  test "on? defaults to false" do
    refute ChaoticJob::Switch.on?
  end

  test "off? defaults to true" do
    assert ChaoticJob::Switch.off?
  end

  test "on? returns true after on!" do
    ChaoticJob::Switch.on!
    assert ChaoticJob::Switch.on?
  end

  test "on? returns false after off!" do
    ChaoticJob::Switch.off!
    refute ChaoticJob::Switch.on?
  end

  test "off? returns false after on!" do
    ChaoticJob::Switch.on!
    refute ChaoticJob::Switch.off?
  end

  test "off? returns true after off!" do
    ChaoticJob::Switch.off!
    assert ChaoticJob::Switch.off?
  end
end
