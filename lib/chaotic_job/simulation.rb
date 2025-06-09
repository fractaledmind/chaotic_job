# frozen_string_literal: true

# Simulation.new(job).run { |scenario| ... }
# Simulation.new(job).variants
# Simulation.new(job).scenarios
module ChaoticJob
  class Simulation
    def initialize(job, callstack: nil, variations: nil, test: nil, seed: nil)
      @template = job
      @callstack = callstack || capture_callstack
      @variations = variations
      @test = test
      @seed = seed || Random.new_seed
      @random = Random.new(@seed)

      raise Error.new("callstack must be a generated via ChaoticJob::Tracer") unless @callstack.is_a?(Stack)
    end

    def run(&assertions)
      @template.class.retry_on RetryableError, attempts: 3, wait: 1, jitter: 0

      debug "👾 Running #{@variations || "all"} simulations of the total #{variants.size} possibilities..."

      scenarios.map do |scenario|
        run_scenario(scenario, &assertions)
        print "·"
      end
    end

    def variants
      error_locations = @callstack.map do |event, key|
        ["before_#{event}", key]
      end

      return error_locations if @variations.nil?

      error_locations.sample(@variations, random: @random)
    end

    def scenarios
      variants.map do |(event, key)|
        job = clone_job_template
        glitch = Glitch.public_send(event, key)
        Scenario.new(job, glitch: glitch)
      end
    end

    private

    def capture_callstack
      job_class = @template.class
      job_file_path = job_class.instance_method(:perform).source_location&.first
      tracer = Tracer.new { |tp| tp.path == job_file_path || tp.defined_class == job_class }
      callstack = tracer.capture { @template.dup.perform_now }

      @template.class.queue_adapter.enqueued_jobs = []
      callstack
    end

    def run_scenario(scenario, &assertions)
      debug "👾 Running simulation with scenario: #{scenario}"
      @test.before_setup
      @test.simulation_scenario = scenario
      scenario.run
      @test.after_teardown
      @test.assert scenario.glitched?, "Scenario did not execute glitch: #{scenario.glitch}"
      assertions.call(scenario)
    ensure
      @test.simulation_scenario = nil
    end

    def clone_job_template
      serialized_template = @template.serialize
      job = ActiveJob::Base.deserialize(serialized_template)
      job.exception_executions = {}
      job
    end

    def debug(...)
      @template.logger.debug(...)
    end
  end
end
