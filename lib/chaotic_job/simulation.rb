# frozen_string_literal: true

# Simulation.new(job).run { |scenario| ... }
# Simulation.new(job).variants
# Simulation.new(job).scenarios
module ChaoticJob
  class Simulation
    def initialize(job, callstack: nil, variations: nil, test: nil, seed: nil, perform_only_jobs_within: nil)
      @template = job
      @callstack = callstack || capture_callstack
      @variations = variations
      @test = test
      @seed = seed || Random.new_seed
      @random = Random.new(@seed)
      @perform_only_jobs_within = perform_only_jobs_within

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
        job.job_id = [job.job_id.split("-").first, glitch.event, glitch.key].join("-")
        Scenario.new(job, glitch: glitch)
      end
    end

    private

    def capture_callstack
      tracer = Tracer.new { |tp| tp.defined_class == @template.class }
      callstack = tracer.capture do
        @template.dup.enqueue
        # run the template job as well as any other jobs it may enqueue
        Performer.perform_all
      end

      @template.class.queue_adapter.enqueued_jobs = []
      callstack
    end

    def run_scenario(scenario, &assertions)
      debug "👾 Running simulation with scenario: #{scenario}"
      @test.before_setup
      @test.simulation_scenario = scenario

      if @perform_only_jobs_within
        scenario.run do
          Performer.perform_all_before(@perform_only_jobs_within)
          assertions.call(scenario)
        end
      else
        scenario.run
        assertions.call(scenario)
      end

      @test.after_teardown
      @test.assert scenario.glitched?, "Scenario did not execute glitch: #{scenario.glitch}"
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
