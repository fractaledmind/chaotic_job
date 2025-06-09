# frozen_string_literal: true

require "test_helper"

class ChaoticJob::GlitchTest < ActiveJob::TestCase
  test "glitch before a line execution" do
    class Job5 < ActiveJob::Base
      def perform
        step_1
        step_2
      end

      def step_1
        ChaoticJob.log_to_journal!(:step_1)
      end

      def step_2
        ChaoticJob.log_to_journal!(:step_2)
      end
    end

    glitch = ChaoticJob::Glitch.before_line("#{__FILE__}:18") do
      ChaoticJob.log_to_journal!(:glitch)
    end
    glitch.inject! { Job5.perform_now }

    assert_equal [:step_1, :glitch, :step_2], ChaoticJob.journal_entries
    assert glitch.executed?
  end

  test "glitch before an instance method call" do
    class Job6 < ActiveJob::Base
      def perform
        step_1
        step_2
      end

      def step_1
        ChaoticJob.log_to_journal!(:step_1)
      end

      def step_2
        ChaoticJob.log_to_journal!(:step_2)
      end
    end

    glitch = ChaoticJob::Glitch.before_call("#{Job6.name}#step_2") do
      ChaoticJob.log_to_journal!(:glitch)
    end
    glitch.inject! { Job6.perform_now }

    assert_equal [:step_1, :glitch, :step_2], ChaoticJob.journal_entries
    assert glitch.executed?
  end

  test "glitch before an instance method call with non-matching required argument matcher" do
    class Job7 < ActiveJob::Base
      def perform
        step_1
        step_2("REQUIRED")
      end

      def step_1
        ChaoticJob.log_to_journal!(:step_1)
      end

      def step_2(required_argument)
        ChaoticJob.log_to_journal!(:step_2)
      end
    end

    glitch = ChaoticJob::Glitch.before_call("#{Job7.name}#step_2", Integer) do
      ChaoticJob.log_to_journal!(:glitch)
    end
    glitch.inject! { Job7.perform_now }

    assert_equal [:step_1, :step_2], ChaoticJob.journal_entries
    refute glitch.executed?
  end

  test "glitch before an instance method call with matching required argument matcher" do
    class Job8 < ActiveJob::Base
      def perform
        step_1
        step_2("REQUIRED")
      end

      def step_1
        ChaoticJob.log_to_journal!(:step_1)
      end

      def step_2(required_argument)
        ChaoticJob.log_to_journal!(:step_2)
      end
    end

    glitch = ChaoticJob::Glitch.before_call("#{Job8.name}#step_2", String) do
      ChaoticJob.log_to_journal!(:glitch)
    end
    glitch.inject! { Job8.perform_now }

    assert_equal [:step_1, :glitch, :step_2], ChaoticJob.journal_entries
    assert glitch.executed?
  end

  test "glitch before an instance method call with non-matching optional argument matcher" do
    class Job9 < ActiveJob::Base
      def perform
        step_1
        step_2("OPTIONAL")
      end

      def step_1
        ChaoticJob.log_to_journal!(:step_1)
      end

      def step_2(optional_argument = nil)
        ChaoticJob.log_to_journal!(:step_2)
      end
    end

    glitch = ChaoticJob::Glitch.before_call("#{Job9.name}#step_2", Integer) do
      ChaoticJob.log_to_journal!(:glitch)
    end
    glitch.inject! { Job9.perform_now }

    assert_equal [:step_1, :step_2], ChaoticJob.journal_entries
    refute glitch.executed?
  end

  test "glitch before an instance method call with matching optional argument matcher" do
    class Job10 < ActiveJob::Base
      def perform
        step_1
        step_2("OPTIONAL")
      end

      def step_1
        ChaoticJob.log_to_journal!(:step_1)
      end

      def step_2(optional_argument = nil)
        ChaoticJob.log_to_journal!(:step_2)
      end
    end

    glitch = ChaoticJob::Glitch.before_call("#{Job10.name}#step_2", String) do
      ChaoticJob.log_to_journal!(:glitch)
    end
    glitch.inject! { Job10.perform_now }

    assert_equal [:step_1, :glitch, :step_2], ChaoticJob.journal_entries
    assert glitch.executed?
  end

  test "glitch before an instance method call with non-matching splat argument partial matcher" do
    class Job11 < ActiveJob::Base
      def perform
        step_1
        step_2("SPLAT 1", "SPLAT 2")
      end

      def step_1
        ChaoticJob.log_to_journal!(:step_1)
      end

      def step_2(*splat_arguments)
        ChaoticJob.log_to_journal!(:step_2)
      end
    end

    glitch = ChaoticJob::Glitch.before_call("#{Job11.name}#step_2", Integer) do
      ChaoticJob.log_to_journal!(:glitch)
    end
    glitch.inject! { Job11.perform_now }

    assert_equal [:step_1, :step_2], ChaoticJob.journal_entries
    refute glitch.executed?
  end

  test "glitch before an instance method call with matching splat argument partial matcher" do
    class Job12 < ActiveJob::Base
      def perform
        step_1
        step_2("SPLAT 1", "SPLAT 2")
      end

      def step_1
        ChaoticJob.log_to_journal!(:step_1)
      end

      def step_2(*splat_arguments)
        ChaoticJob.log_to_journal!(:step_2)
      end
    end

    glitch = ChaoticJob::Glitch.before_call("#{Job12.name}#step_2", String) do
      ChaoticJob.log_to_journal!(:glitch)
    end
    glitch.inject! { Job12.perform_now }

    assert_equal [:step_1, :glitch, :step_2], ChaoticJob.journal_entries
    assert glitch.executed?
  end

  test "glitch before an instance method call with non-matching keyword argument matcher" do
    class Job13 < ActiveJob::Base
      def perform
        step_1
        step_2(required: "KEYWORD")
      end

      def step_1
        ChaoticJob.log_to_journal!(:step_1)
      end

      def step_2(required:)
        ChaoticJob.log_to_journal!(:step_2)
      end
    end

    glitch = ChaoticJob::Glitch.before_call("#{Job13.name}#step_2", required: Integer) do
      ChaoticJob.log_to_journal!(:glitch)
    end
    glitch.inject! { Job13.perform_now }

    assert_equal [:step_1, :step_2], ChaoticJob.journal_entries
    refute glitch.executed?
  end

  test "glitch before an instance method call with matching keyword argument matcher" do
    class Job14 < ActiveJob::Base
      def perform
        step_1
        step_2(required: "KEYWORD")
      end

      def step_1
        ChaoticJob.log_to_journal!(:step_1)
      end

      def step_2(required:)
        ChaoticJob.log_to_journal!(:step_2)
      end
    end

    glitch = ChaoticJob::Glitch.before_call("#{Job14.name}#step_2", required: String) do
      ChaoticJob.log_to_journal!(:glitch)
    end
    glitch.inject! { Job14.perform_now }

    assert_equal [:step_1, :glitch, :step_2], ChaoticJob.journal_entries
    assert glitch.executed?
  end

  test "glitch before an instance method call with non-matching optional keyword argument matcher" do
    class Job15 < ActiveJob::Base
      def perform
        step_1
        step_2(optional: "KEYWORD")
      end

      def step_1
        ChaoticJob.log_to_journal!(:step_1)
      end

      def step_2(optional: nil)
        ChaoticJob.log_to_journal!(:step_2)
      end
    end

    glitch = ChaoticJob::Glitch.before_call("#{Job15.name}#step_2", optional: Integer) do
      ChaoticJob.log_to_journal!(:glitch)
    end
    glitch.inject! { Job15.perform_now }

    assert_equal [:step_1, :step_2], ChaoticJob.journal_entries
    refute glitch.executed?
  end

  test "glitch before an instance method call with matching optional keyword argument matcher" do
    class Job16 < ActiveJob::Base
      def perform
        step_1
        step_2(optional: "KEYWORD")
      end

      def step_1
        ChaoticJob.log_to_journal!(:step_1)
      end

      def step_2(optional: nil)
        ChaoticJob.log_to_journal!(:step_2)
      end
    end

    glitch = ChaoticJob::Glitch.before_call("#{Job16.name}#step_2", optional: String) do
      ChaoticJob.log_to_journal!(:glitch)
    end
    glitch.inject! { Job16.perform_now }

    assert_equal [:step_1, :glitch, :step_2], ChaoticJob.journal_entries
    assert glitch.executed?
  end

  test "glitch before an instance method call with non-matching double splat argument partial matcher" do
    class Job17 < ActiveJob::Base
      def perform
        step_1
        step_2(splat_1: "DOUBLE SPLAT 1", splat_2: "DOUBLE SPLAT 2")
      end

      def step_1
        ChaoticJob.log_to_journal!(:step_1)
      end

      def step_2(**double_splat_arguments)
        ChaoticJob.log_to_journal!(:step_2)
      end
    end

    glitch = ChaoticJob::Glitch.before_call("#{Job17.name}#step_2", splat_1: Integer) do
      ChaoticJob.log_to_journal!(:glitch)
    end
    glitch.inject! { Job17.perform_now }

    assert_equal [:step_1, :step_2], ChaoticJob.journal_entries
    refute glitch.executed?
  end

  test "glitch before an instance method call with matching double splat argument partial matcher" do
    class Job18 < ActiveJob::Base
      def perform
        step_1
        step_2(splat_1: "DOUBLE SPLAT 1", splat_2: "DOUBLE SPLAT 2")
      end

      def step_1
        ChaoticJob.log_to_journal!(:step_1)
      end

      def step_2(**double_splat_arguments)
        ChaoticJob.log_to_journal!(:step_2)
      end
    end

    glitch = ChaoticJob::Glitch.before_call("#{Job18.name}#step_2", splat_1: String) do
      ChaoticJob.log_to_journal!(:glitch)
    end
    glitch.inject! { Job18.perform_now }

    assert_equal [:step_1, :glitch, :step_2], ChaoticJob.journal_entries
    assert glitch.executed?
  end

  test "glitch before an instance method call with matching partial matcher for jumbo method signature" do
    class Job19 < ActiveJob::Base
      def perform
        step_1
        step_2(
          "REQUIRED",
          "OPTIONAL",
          "SPLAT 1", "SPLAT 2",
          req_kw: "REQUIRED",
          opt_kw: "OPTIONAL",
          splat_1: "DOUBLE SPLAT 1", splat_2: "DOUBLE SPLAT 2"
        )
      end

      def step_1
        ChaoticJob.log_to_journal!(:step_1)
      end

      def step_2(req_pos, opt_pos = nil, *splat_args, req_kw:, opt_kw: nil, **double_splat_args)
        ChaoticJob.log_to_journal!(:step_2)
      end
    end

    glitch = ChaoticJob::Glitch.before_call("#{Job19.name}#step_2", splat_1: String) do
      ChaoticJob.log_to_journal!(:glitch)
    end
    glitch.inject! { Job19.perform_now }

    assert_equal [:step_1, :glitch, :step_2], ChaoticJob.journal_entries
    assert glitch.executed?
  end

  test "glitch before an instance method return" do
    class Job20 < ActiveJob::Base
      def perform
        step_1
        step_2
      end

      def step_1
        ChaoticJob.log_to_journal!(:step_1)
      end

      def step_2
        ChaoticJob.log_to_journal!(:step_2)
      end
    end

    glitch = ChaoticJob::Glitch.before_return("#{Job20.name}#step_2") do
      ChaoticJob.log_to_journal!(:glitch)
    end
    glitch.inject! { Job20.perform_now }

    assert_equal [:step_1, :step_2, :glitch], ChaoticJob.journal_entries
    assert glitch.executed?
  end

  test "glitch before an instance method return with non-matching return value matcher" do
    class Job21 < ActiveJob::Base
      def perform
        step_1
        step_2
      end

      def step_1
        ChaoticJob.log_to_journal!(:step_1)
      end

      def step_2
        ChaoticJob.log_to_journal!(:step_2)
      end
    end

    glitch = ChaoticJob::Glitch.before_return("#{Job21.name}#step_2", String) do
      ChaoticJob.log_to_journal!(:glitch)
    end
    glitch.inject! { Job21.perform_now }

    assert_equal [:step_1, :step_2], ChaoticJob.journal_entries
    refute glitch.executed?
  end

  test "glitch before an instance method return with matching return value matcher" do
    class Job22 < ActiveJob::Base
      def perform
        step_1
        step_2
      end

      def step_1
        ChaoticJob.log_to_journal!(:step_1)
      end

      def step_2
        ChaoticJob.log_to_journal!(:step_2)
      end
    end

    glitch = ChaoticJob::Glitch.before_return("#{Job22.name}#step_2", Symbol) do
      ChaoticJob.log_to_journal!(:glitch)
    end
    glitch.inject! { Job22.perform_now }

    assert_equal [:step_1, :step_2, :glitch], ChaoticJob.journal_entries
    assert glitch.executed?
  end

  test "glitch before a class method call" do
    module Mod1
      def self.perform
        step_1
        step_2
      end

      def self.step_1
        ChaoticJob.log_to_journal!(:step_1)
      end

      def self.step_2
        ChaoticJob.log_to_journal!(:step_2)
      end
    end

    glitch = ChaoticJob::Glitch.before_call("#{Mod1.name}.step_2") do
      ChaoticJob.log_to_journal!(:glitch)
    end
    glitch.inject! { Mod1.perform }

    assert_equal [:step_1, :glitch, :step_2], ChaoticJob.journal_entries
    assert glitch.executed?
  end

  test "glitch before a class method call with non-matching required argument matcher" do
    module Mod2
      def self.perform
        step_1
        step_2("REQUIRED")
      end

      def self.step_1
        ChaoticJob.log_to_journal!(:step_1)
      end

      def self.step_2(required_argument)
        ChaoticJob.log_to_journal!(:step_2)
      end
    end

    glitch = ChaoticJob::Glitch.before_call("#{Mod2.name}.step_2", Integer) do
      ChaoticJob.log_to_journal!(:glitch)
    end
    glitch.inject! { Mod2.perform }

    assert_equal [:step_1, :step_2], ChaoticJob.journal_entries
    refute glitch.executed?
  end

  test "glitch before a class method call with matching required argument matcher" do
    module Mod3
      def self.perform
        step_1
        step_2("REQUIRED")
      end

      def self.step_1
        ChaoticJob.log_to_journal!(:step_1)
      end

      def self.step_2(required_argument)
        ChaoticJob.log_to_journal!(:step_2)
      end
    end

    glitch = ChaoticJob::Glitch.before_call("#{Mod3.name}.step_2", String) do
      ChaoticJob.log_to_journal!(:glitch)
    end
    glitch.inject! { Mod3.perform }

    assert_equal [:step_1, :glitch, :step_2], ChaoticJob.journal_entries
    assert glitch.executed?
  end

  test "glitch before a class method call with non-matching optional argument matcher" do
    module Mod4
      def self.perform
        step_1
        step_2("OPTIONAL")
      end

      def self.step_1
        ChaoticJob.log_to_journal!(:step_1)
      end

      def self.step_2(optional_argument = nil)
        ChaoticJob.log_to_journal!(:step_2)
      end
    end

    glitch = ChaoticJob::Glitch.before_call("#{Mod4.name}.step_2", Integer) do
      ChaoticJob.log_to_journal!(:glitch)
    end
    glitch.inject! { Mod4.perform }

    assert_equal [:step_1, :step_2], ChaoticJob.journal_entries
    refute glitch.executed?
  end

  test "glitch before a class method call with matching optional argument matcher" do
    module Mod5
      def self.perform
        step_1
        step_2("OPTIONAL")
      end

      def self.step_1
        ChaoticJob.log_to_journal!(:step_1)
      end

      def self.step_2(optional_argument = nil)
        ChaoticJob.log_to_journal!(:step_2)
      end
    end

    glitch = ChaoticJob::Glitch.before_call("#{Mod5.name}.step_2", String) do
      ChaoticJob.log_to_journal!(:glitch)
    end
    glitch.inject! { Mod5.perform }

    assert_equal [:step_1, :glitch, :step_2], ChaoticJob.journal_entries
    assert glitch.executed?
  end

  test "glitch before a class method call with non-matching splat argument partial matcher" do
    module Mod6
      def self.perform
        step_1
        step_2("SPLAT 1", "SPLAT 2")
      end

      def self.step_1
        ChaoticJob.log_to_journal!(:step_1)
      end

      def self.step_2(*splat_arguments)
        ChaoticJob.log_to_journal!(:step_2)
      end
    end

    glitch = ChaoticJob::Glitch.before_call("#{Mod6.name}.step_2", Integer) do
      ChaoticJob.log_to_journal!(:glitch)
    end
    glitch.inject! { Mod6.perform }

    assert_equal [:step_1, :step_2], ChaoticJob.journal_entries
    refute glitch.executed?
  end

  test "glitch before a class method call with matching splat argument partial matcher" do
    module Mod7
      def self.perform
        step_1
        step_2("SPLAT 1", "SPLAT 2")
      end

      def self.step_1
        ChaoticJob.log_to_journal!(:step_1)
      end

      def self.step_2(*splat_arguments)
        ChaoticJob.log_to_journal!(:step_2)
      end
    end

    glitch = ChaoticJob::Glitch.before_call("#{Mod7.name}.step_2", String) do
      ChaoticJob.log_to_journal!(:glitch)
    end
    glitch.inject! { Mod7.perform }

    assert_equal [:step_1, :glitch, :step_2], ChaoticJob.journal_entries
    assert glitch.executed?
  end

  test "glitch before a class method call with non-matching keyword argument matcher" do
    module Mod8
      def self.perform
        step_1
        step_2(required: "KEYWORD")
      end

      def self.step_1
        ChaoticJob.log_to_journal!(:step_1)
      end

      def self.step_2(required:)
        ChaoticJob.log_to_journal!(:step_2)
      end
    end

    glitch = ChaoticJob::Glitch.before_call("#{Mod8.name}.step_2", required: Integer) do
      ChaoticJob.log_to_journal!(:glitch)
    end
    glitch.inject! { Mod8.perform }

    assert_equal [:step_1, :step_2], ChaoticJob.journal_entries
    refute glitch.executed?
  end

  test "glitch before a class method call with matching keyword argument matcher" do
    module Mod9
      def self.perform
        step_1
        step_2(required: "KEYWORD")
      end

      def self.step_1
        ChaoticJob.log_to_journal!(:step_1)
      end

      def self.step_2(required:)
        ChaoticJob.log_to_journal!(:step_2)
      end
    end

    glitch = ChaoticJob::Glitch.before_call("#{Mod9.name}.step_2", required: String) do
      ChaoticJob.log_to_journal!(:glitch)
    end
    glitch.inject! { Mod9.perform }

    assert_equal [:step_1, :glitch, :step_2], ChaoticJob.journal_entries
    assert glitch.executed?
  end

  test "glitch before a class method call with non-matching optional keyword argument matcher" do
    module Mod10
      def self.perform
        step_1
        step_2(optional: "KEYWORD")
      end

      def self.step_1
        ChaoticJob.log_to_journal!(:step_1)
      end

      def self.step_2(optional: nil)
        ChaoticJob.log_to_journal!(:step_2)
      end
    end

    glitch = ChaoticJob::Glitch.before_call("#{Mod10.name}.step_2", optional: Integer) do
      ChaoticJob.log_to_journal!(:glitch)
    end
    glitch.inject! { Mod10.perform }

    assert_equal [:step_1, :step_2], ChaoticJob.journal_entries
    refute glitch.executed?
  end

  test "glitch before a class method call with matching optional keyword argument matcher" do
    module Mod11
      def self.perform
        step_1
        step_2(optional: "KEYWORD")
      end

      def self.step_1
        ChaoticJob.log_to_journal!(:step_1)
      end

      def self.step_2(optional: nil)
        ChaoticJob.log_to_journal!(:step_2)
      end
    end

    glitch = ChaoticJob::Glitch.before_call("#{Mod11.name}.step_2", optional: String) do
      ChaoticJob.log_to_journal!(:glitch)
    end
    glitch.inject! { Mod11.perform }

    assert_equal [:step_1, :glitch, :step_2], ChaoticJob.journal_entries
    assert glitch.executed?
  end

  test "glitch before a class method call with non-matching double splat argument partial matcher" do
    module Mod12
      def self.perform
        step_1
        step_2(splat_1: "DOUBLE SPLAT 1", splat_2: "DOUBLE SPLAT 2")
      end

      def self.step_1
        ChaoticJob.log_to_journal!(:step_1)
      end

      def self.step_2(**double_splat_arguments)
        ChaoticJob.log_to_journal!(:step_2)
      end
    end

    glitch = ChaoticJob::Glitch.before_call("#{Mod12.name}.step_2", splat_1: Integer) do
      ChaoticJob.log_to_journal!(:glitch)
    end
    glitch.inject! { Mod12.perform }

    assert_equal [:step_1, :step_2], ChaoticJob.journal_entries
    refute glitch.executed?
  end

  test "glitch before a class method call with matching double splat argument partial matcher" do
    module Mod13
      def self.perform
        step_1
        step_2(splat_1: "DOUBLE SPLAT 1", splat_2: "DOUBLE SPLAT 2")
      end

      def self.step_1
        ChaoticJob.log_to_journal!(:step_1)
      end

      def self.step_2(**double_splat_arguments)
        ChaoticJob.log_to_journal!(:step_2)
      end
    end

    glitch = ChaoticJob::Glitch.before_call("#{Mod13.name}.step_2", splat_1: String) do
      ChaoticJob.log_to_journal!(:glitch)
    end
    glitch.inject! { Mod13.perform }

    assert_equal [:step_1, :glitch, :step_2], ChaoticJob.journal_entries
    assert glitch.executed?
  end

  test "glitch before a class method call with matching partial matcher for jumbo method signature" do
    module Mod14
      def self.perform
        step_1
        step_2(
          "REQUIRED",
          "OPTIONAL",
          "SPLAT 1", "SPLAT 2",
          req_kw: "REQUIRED",
          opt_kw: "OPTIONAL",
          splat_1: "DOUBLE SPLAT 1", splat_2: "DOUBLE SPLAT 2"
        )
      end

      def self.step_1
        ChaoticJob.log_to_journal!(:step_1)
      end

      def self.step_2(req_pos, opt_pos = nil, *splat_args, req_kw:, opt_kw: nil, **double_splat_args)
        ChaoticJob.log_to_journal!(:step_2)
      end
    end

    glitch = ChaoticJob::Glitch.before_call("#{Mod14.name}.step_2", splat_1: String) do
      ChaoticJob.log_to_journal!(:glitch)
    end
    glitch.inject! { Mod14.perform }

    assert_equal [:step_1, :glitch, :step_2], ChaoticJob.journal_entries
    assert glitch.executed?
  end

  test "glitch before a class method return" do
    module Mod15
      def self.perform
        step_1
        step_2
      end

      def self.step_1
        ChaoticJob.log_to_journal!(:step_1)
      end

      def self.step_2
        ChaoticJob.log_to_journal!(:step_2)
      end
    end

    glitch = ChaoticJob::Glitch.before_return("#{Mod15.name}.step_2") do
      ChaoticJob.log_to_journal!(:glitch)
    end
    glitch.inject! { Mod15.perform }

    assert_equal [:step_1, :step_2, :glitch], ChaoticJob.journal_entries
    assert glitch.executed?
  end

  test "glitch before a class method return with non-matching return value matcher" do
    module Mod16
      def self.perform
        step_1
        step_2
      end

      def self.step_1
        ChaoticJob.log_to_journal!(:step_1)
      end

      def self.step_2
        ChaoticJob.log_to_journal!(:step_2)
      end
    end

    glitch = ChaoticJob::Glitch.before_return("#{Mod16.name}.step_2", String) do
      ChaoticJob.log_to_journal!(:glitch)
    end
    glitch.inject! { Mod16.perform }

    assert_equal [:step_1, :step_2], ChaoticJob.journal_entries
    refute glitch.executed?
  end

  test "glitch before a class method return with matching return value matcher" do
    module Mod17
      def self.perform
        step_1
        step_2
      end

      def self.step_1
        ChaoticJob.log_to_journal!(:step_1)
      end

      def self.step_2
        ChaoticJob.log_to_journal!(:step_2)
      end
    end

    glitch = ChaoticJob::Glitch.before_return("#{Mod17.name}.step_2", Symbol) do
      ChaoticJob.log_to_journal!(:glitch)
    end
    glitch.inject! { Mod17.perform }

    assert_equal [:step_1, :step_2, :glitch], ChaoticJob.journal_entries
    assert glitch.executed?
  end
end
