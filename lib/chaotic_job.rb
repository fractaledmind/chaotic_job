# frozen_string_literal: true

require_relative "chaotic_job/version"
require_relative "chaotic_job/journal"
require_relative "chaotic_job/performer"
require_relative "chaotic_job/tracer"
require_relative "chaotic_job/glitch"
require_relative "chaotic_job/scenario"
require_relative "chaotic_job/simulation"
require_relative "chaotic_job/switch"
require_relative "chaotic_job/race"
require_relative "chaotic_job/relay"
require "set"

module ChaoticJob
  Error = Class.new(StandardError)
  RetryableError = Class.new(Error)
  Stack = Set

  def self.log_to_journal!(item = nil, scope: nil)
    if item && scope
      Journal.log(item, scope: scope)
    elsif item
      Journal.log(item)
    elsif scope
      Journal.log(scope: scope)
    else
      Journal.log
    end
  end

  def self.push_to_journal!(item = nil, scope: nil)
    if item && scope
      Journal.push(item, scope: scope)
    elsif item
      Journal.push(item)
    elsif scope
      Journal.push(scope: scope)
    else
      Journal.push
    end
  end

  def self.journal_entries(scope: nil)
    if scope
      Journal.entries(scope: scope)
    else
      Journal.entries
    end
  end

  def self.journal_size(scope: nil)
    if scope
      Journal.size(scope: scope)
    else
      Journal.size
    end
  end

  def self.top_journal_entry(scope: nil)
    if scope
      Journal.top(scope: scope)
    else
      Journal.top
    end
  end

  def self.switch_on?
    Switch.on?
  end

  def self.switch_off?
    Switch.off?
  end

  def self.switch_on!
    Switch.on!
  end

  def self.switch_off!
    Switch.off!
  end

  module Helpers
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def test_simulation(job, tracing: nil, variations: nil, callstack: nil, perform_only_jobs_within: nil, &block)
        seed = defined?(RSpec) ? RSpec.configuration.seed : Minitest.seed
        kwargs = {test: self, seed: seed}
        kwargs[:tracing] = tracing if tracing
        kwargs[:variations] = variations if variations
        kwargs[:callstack] = callstack if callstack
        kwargs[:perform_only_jobs_within] = perform_only_jobs_within if perform_only_jobs_within

        Simulation.new(job, **kwargs).define(&block)
      end
    end

    def perform_all_jobs
      Performer.perform_all
    end

    def perform_all_jobs_before(time)
      Performer.perform_all_before(time)
    end
    alias_method :perform_all_jobs_within, :perform_all_jobs_before

    def perform_all_jobs_after(time)
      Performer.perform_all_after(time)
    end

    def run_scenario(job, glitch:, raise: nil, capture: nil, &block)
      kwargs = {}

      kwargs[:glitch] = glitch
      kwargs[:raise] = binding.local_variable_get(:raise) if binding.local_variable_get(:raise)
      kwargs[:capture] = capture if capture

      if block
        Scenario.new(job, **kwargs).run(&block)
      else
        Scenario.new(job, **kwargs).run
      end
    end

    def glitch_before_line(key, &block)
      Glitch.before_line(key, &block)
    end

    def glitch_before_call(key, ...)
      Glitch.before_call(key, ...)
    end

    def glitch_before_return(key, return_type = nil, &block)
      Glitch.before_return(key, return_type, &block)
    end
  end
end
