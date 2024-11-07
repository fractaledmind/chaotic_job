# frozen_string_literal: true

require_relative "chaotic_job/version"
require_relative "chaotic_job/journal"
require_relative "chaotic_job/performer"
require_relative "chaotic_job/glitch"
require_relative "chaotic_job/scenario"
require_relative "chaotic_job/simulation"

module ChaoticJob
  class RetryableError < StandardError; end

  module Helpers
    def run_simulation(job, ..., &block)
      Simulation.new(job, test: self, ...).run(&block)
    end

    def run_scenario(job)
      Scenario.new(job).run
    end
  end
end
