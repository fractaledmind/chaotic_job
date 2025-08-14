# frozen_string_literal: true

# Simulation.new(job).define { |scenario| ... }
module ChaoticJob
  class Simulation
    def initialize(job, callstack: nil, variations: nil, test: nil, seed: nil, perform_only_jobs_within: nil, capture: nil)
      @template = job
      @callstack = callstack || capture_callstack
      @variations = variations
      @test = test
      @seed = seed || Random.new_seed
      @random = Random.new(@seed)
      @perform_only_jobs_within = perform_only_jobs_within
      @capture = capture

      @template.class.retry_on RetryableError, attempts: 3, wait: 1, jitter: 0
      raise Error.new("callstack must be a generated via ChaoticJob::Tracer") unless @callstack.is_a?(Stack)
    end

    def define(&assertions)
      debug "👾 Defining #{@variations || "all"} simulated scenarios of the total #{variants.size} possibilities..."

      scenarios.each do |scenario|
        define_test_for(scenario, &assertions)
      end

      # Since the callstack capture likely touches the database and this code runs during test class definition,
      # we need to disconnect the database connection before possible parallel test forking
      ActiveRecord::Base.connection_pool.disconnect! if ActiveRecord::Base.connected?
    end

    def define_test_for(scenario, &assertions)
      if defined?(RSpec)
        define_rspec_test_for(scenario, &assertions)
      else
        define_minitest_test_for(scenario, &assertions)
      end
    end

    def define_rspec_test_for(scenario, &assertions)
    end

    def define_minitest_test_for(scenario, &assertions)
      test_method_name = "test_simulation_scenario_before_#{scenario.glitch.event}_#{scenario.glitch.key}"

      @test.define_method(test_method_name) do
        run_scenario(scenario, &assertions)

        assert scenario.glitched?, "Scenario did not execute glitch: #{scenario.glitch}"
      end
    end

    def run_scenario(scenario, &assertions)
      if @perform_only_jobs_within
        scenario.run do
          Performer.perform_all_before(@perform_only_jobs_within)
          instance_exec(scenario, &assertions)
        end
      else
        scenario.run
        instance_exec(scenario, &assertions)
      end
    end

    private

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
        Scenario.new(job, glitch: glitch, capture: @capture)
      end
    end

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
