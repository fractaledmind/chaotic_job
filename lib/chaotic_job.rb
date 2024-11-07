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

    def run_simulation(job, &block)
      Simulation.new(job, test: self).run(&block)
    end

    def run_scenario(job, glitch: nil, glitches: nil)
      arg = glitches || [glitch]
      Scenario.new(job, glitches: arg).run
    end
  end
end
