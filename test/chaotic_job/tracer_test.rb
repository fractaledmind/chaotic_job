# frozen_string_literal: true

require "test_helper"

class ChaoticJob::TracerTest < ActiveJob::TestCase
  test "initializes with constraint block" do
    tracer = ChaoticJob::Tracer.new { |tp| tp.path.start_with?("test") }

    assert_not_nil tracer
  end

  test "capture returns a Stack" do
    tracer = ChaoticJob::Tracer.new { |tp| true }
    result = tracer.capture { 1 + 1 }

    assert_instance_of ChaoticJob::Stack, result
  end

  test "capture traces line events" do
    tracer = ChaoticJob::Tracer.new { |tp| tp.path == __FILE__ }

    result = tracer.capture do
      x = 1
      y = 2
      x + y
    end

    assert_equal 3, result.size
    assert_equal 3, result.count { |event, _| event == :line }
  end

  test "capture traces call and return events" do
    tracer = ChaoticJob::Tracer.new { |tp| tp.path == __FILE__ }

    def test_method
      "hello"
    end

    result = tracer.capture { test_method }

    assert_equal 4, result.size
    assert_equal 1, result.count { |event, _| event == :call }
    assert_equal 1, result.count { |event, _| event == :return }
    assert_equal 2, result.count { |event, _| event == :line }
  end

  test "constraint filters events" do
    # Only trace events from this file
    tracer = ChaoticJob::Tracer.new { |tp| tp.path == __FILE__ }

    result = tracer.capture do
      "hello".upcase  # This should be traced
      Time.now        # This should not be traced (different file)
    end

    assert_equal 2, result.size
    assert_equal 0, result.count { |event, _| event == :call }
    assert_equal 0, result.count { |event, _| event == :return }
    assert_equal 2, result.count { |event, _| event == :line }
  end

  test "line key format and stuff" do
    tracer = ChaoticJob::Tracer.new { |tp| tp.path == __FILE__ }

    result = tracer.capture { 42 }

    assert_equal 1, result.size
    assert_equal 0, result.count { |event, _| event == :call }
    assert_equal 0, result.count { |event, _| event == :return }
    assert_equal 1, result.count { |event, _| event == :line }
    assert result.all? { |_, key| key.include?(__FILE__) && key.include?(":") }
  end

  test "call key format for instance methods" do
    tracer = ChaoticJob::Tracer.new { |tp| tp.path == __FILE__ }

    def test_instance_method
      "test"
    end

    result = tracer.capture { test_instance_method }

    assert_equal 4, result.size
    assert_equal 1, result.count { |event, _| event == :call }
    assert_equal 1, result.count { |event, _| event == :return }
    assert_equal 2, result.count { |event, _| event == :line }
    assert_equal 1, result.count { |event, key| event == :call && key.include?("#test_instance_method") }
  end

  test "excludes tracer class from tracing" do
    tracer = ChaoticJob::Tracer.new { |tp| true }

    result = tracer.capture { 1 + 1 }

    assert_equal 0, result.count { |_, key| key.to_s.include?("ChaoticJob::Tracer") }
  end

  test "empty capture when constraint rejects all" do
    tracer = ChaoticJob::Tracer.new { |tp| false }

    def complex_operation
      arr = [1, 2, 3]
      arr.map { |x| x * 2 }.sum
    end

    result = tracer.capture { complex_operation }

    assert_equal 0, result.size
  end
end
