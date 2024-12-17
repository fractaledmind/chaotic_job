# frozen_string_literal: true

require_relative "chaotic_job/version"
require_relative "chaotic_job/journal"
require_relative "chaotic_job/performer"
require_relative "chaotic_job/glitch"
require_relative "chaotic_job/scenario"
require_relative "chaotic_job/simulation"

module ChaoticJob
  class RetryableError < StandardError
  end

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

  module Helpers
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

    def run_simulation(job, depth: nil, variations: nil, &block)
      seed = defined?(RSpec) ? RSpec.configuration.seed : Minitest.seed
      kwargs = {test: self, seed: seed}
      kwargs[:depth] = depth if depth
      kwargs[:variations] = variations if variations
      Simulation.new(job, **kwargs).run(&block)
    end

    def run_scenario(job, glitch: nil, glitches: nil, raise: nil, capture: nil, &block)
      kwargs = {glitches: glitches || [glitch]}
      kwargs[:raise] = raise if raise
      kwargs[:capture] = capture if capture
      if block
        Scenario.new(job, **kwargs).run(&block)
      else
        Scenario.new(job, **kwargs).run
      end
    end
  end
end
