# frozen_string_literal: true

# Simulation.new(job_or_workload).define { |scenario| assert something }

module ChaoticJob
  class Simulation
    attr_reader :callstack, :tracing

    def initialize(subject, tracing: nil, callstack: nil, variations: nil, test: nil, seed: nil, perform_only_jobs_within: nil, capture: nil)
      @template = Workload.coerce(subject)
      @tracing = Array(tracing || @template.tracing)
      @callstack = callstack || capture_callstack
      @variations = variations
      @test = test
      @seed = seed || Random.new_seed
      @random = Random.new(@seed)
      @perform_only_jobs_within = perform_only_jobs_within
      @capture = capture

      raise Error.new("callstack must be a generated via ChaoticJob::Tracer") unless @callstack.is_a?(Stack)
    end

    def define(&assertions)
      debug "👾 Defining #{@variations || "all"} simulated scenarios of the total #{error_locations.size} possibilities..."

      scenarios.each do |scenario|
        define_test_for(scenario, &assertions)
      end

      # Since the callstack capture likely touches the database and this code runs during test class definition,
      # we need to disconnect the database connection before possible parallel test forking
      ActiveRecord::Base.connection_pool.disconnect! if defined?(ActiveRecord) && ActiveRecord::Base.connected?
    end

    private

    def define_test_for(scenario, &assertions)
      if defined?(RSpec)
        define_rspec_test_for(scenario, &assertions)
      else
        define_minitest_test_for(scenario, &assertions)
      end
    end

    def define_rspec_test_for(scenario, &assertions)
      example_name = "test_simulation_scenario_before_#{scenario.glitch.event}_#{scenario.glitch.key}"
      perform_within = @perform_only_jobs_within
      raise_class = scenario.instance_variable_get(:@raise)

      @test.it example_name do
        Simulation.execute_scenario(scenario, perform_within: perform_within, raise_class: raise_class) do
          instance_exec(scenario, &assertions)
        end

        expect(scenario).to be_glitched, "Scenario did not execute glitch: #{scenario.glitch}"
      end
    end

    def define_minitest_test_for(scenario, &assertions)
      test_method_name = "test_simulation_scenario_before_#{scenario.glitch.event}_#{scenario.glitch.key}"
      perform_within = @perform_only_jobs_within
      raise_class = scenario.instance_variable_get(:@raise)

      @test.define_method(test_method_name) do
        Simulation.execute_scenario(scenario, perform_within: perform_within, raise_class: raise_class) do
          instance_exec(scenario, &assertions)
        end

        assert scenario.success?, "Scenario did not execute glitch: #{scenario.glitch}"
      end
    end

    # Class method so it is reachable from inside the generated example /
    # test method, where `self` is the example instance and Simulation's
    # private instance methods are not in scope.
    def self.execute_scenario(scenario, perform_within:, raise_class:, &assertions)
      # `perform_only_jobs_within` is meaningful only for workloads that
      # expose scheduled-work semantics (JobWorkload). For others it is
      # silently ignored — there is no queue to time-box.
      if perform_within && scenario.workload.respond_to?(:perform_within)
        scenario.run do
          scenario.workload.perform_within(perform_within)
          assertions.call
        end
      else
        # A block workload's glitch error escapes scenario.run (Active Job
        # workloads swallow it via retry_on inside the inject!). Catching
        # the configured raise class here keeps the simulation cycle —
        # "run with glitch, then assert the aftermath" — uniform across
        # workload kinds. Unrelated errors still propagate.
        begin
          scenario.run
        rescue *Array(raise_class)
        end
        assertions.call
      end
    end

    def scenarios
      variants.map do |(event, key)|
        workload = @template.clone_for_variant
        glitch = Glitch.public_send(event, key)
        # Active Jobs stamp the variant into job_id for traceable logs; other
        # workloads have no equivalent and ignore the call.
        workload.tag_variant!(glitch) if workload.respond_to?(:tag_variant!)
        Scenario.new(workload, glitch: glitch, capture: @capture)
      end
    end

    def variants
      return error_locations if @variations.nil?

      error_locations.sample(@variations, random: @random)
    end

    def error_locations
      @callstack.map do |event|
        ["before_#{event.type}", event.key]
      end
    end

    def capture_callstack
      tracer = Tracer.new(tracing: @tracing)
      callstack = tracer.capture do
        @template.clone_for_variant.perform!
      end

      # Active Jobs are run during capture via the test queue adapter; clear
      # any residue so the first real scenario starts from an empty queue.
      if @template.respond_to?(:job)
        @template.job.class.queue_adapter.enqueued_jobs = []
      end

      callstack
    end

    def debug(...)
      logger = if @template.respond_to?(:job)
        @template.job.logger
      elsif defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger
        Rails.logger
      else
        Logger.new($stdout)
      end
      logger.debug(...)
    end
  end
end
