# frozen_string_literal: true

require "test_helper"

class ChaoticJob::SwitchTest < ActiveJob::TestCase
  def before_setup
    ChaoticJob::Switch.off!
    super
  end

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

  test "ChaoticJob.switch_on? defaults to false" do
    refute ChaoticJob.switch_on?
  end

  test "ChaoticJob.switch_off? defaults to true" do
    assert ChaoticJob.switch_off?
  end

  test "ChaoticJob.switch_on? returns true after on!" do
    ChaoticJob.switch_on!
    assert ChaoticJob.switch_on?
  end

  test "ChaoticJob.switch_on? returns false after off!" do
    ChaoticJob.switch_off!
    refute ChaoticJob.switch_on?
  end

  test "ChaoticJob.switch_off? returns false after on!" do
    ChaoticJob.switch_on!
    refute ChaoticJob.switch_off?
  end

  test "ChaoticJob.switch_off? returns true after off!" do
    ChaoticJob.switch_off!
    assert ChaoticJob.switch_off?
  end
end
