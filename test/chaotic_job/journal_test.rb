# frozen_string_literal: true

require "test_helper"

class ChaoticJob::JournalTest < ActiveJob::TestCase
  test "logging to journal and checking size" do
    ChaoticJob.log_to_journal!

    assert_equal 1, ChaoticJob.journal_size
  end

  test "logging to journal and checking entries" do
    ChaoticJob.log_to_journal!(:item_1)

    assert_equal [:item_1], ChaoticJob.journal_entries
  end

  test "logging to journal and checking top entry" do
    ChaoticJob.log_to_journal!(:item_1)

    assert_equal :item_1, ChaoticJob.top_journal_entry
  end

  test "logging to journal and checking size with scope" do
    ChaoticJob.log_to_journal!(scope: :test)

    assert_equal 1, ChaoticJob.journal_size(scope: :test)
    assert_equal 0, ChaoticJob.journal_size
  end

  test "logging to journal and checking entries with scope" do
    ChaoticJob.log_to_journal!(:item_1, scope: :test)

    assert_equal [:item_1], ChaoticJob.journal_entries(scope: :test)
    assert_nil ChaoticJob.journal_entries
  end

  test "logging to journal and checking top entry with scope" do
    ChaoticJob.log_to_journal!(:item_1, scope: :test)

    assert_equal :item_1, ChaoticJob.top_journal_entry(scope: :test)
    assert_nil ChaoticJob.top_journal_entry
  end
end
