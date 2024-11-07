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

  module Helpers
    def perform_all
      Performer.perform_all
    end

    def perform_all_within(time)
      Performer.perform_all_within(time)
    end

    def perform_all_before(time)
      Performer.perform_all_before(time)
    end

    def perform_all_after(time)
      Performer.perform_all_after(time)
    end

    def run_simulation(job, depth: nil, variations: nil, &block)
      seed = defined?(RSpec) ? RSpec.configuration.seed : Minitest.seed
      kwargs = {test: self, seed: seed}
      kwargs[:depth] = depth if depth
      kwargs[:variations] = variations if variations
      Simulation.new(job, **kwargs).run(&block)
    end

    def run_scenario(job, glitch: nil, glitches: nil, raise: nil, capture: nil)
      kwargs = {glitches: glitches || [glitch]}
      kwargs[:raise] = raise if raise
      kwargs[:capture] = capture if capture
      Scenario.new(job, **kwargs).run
    end
  end
end
