# frozen_string_literal: true

# Simulation.new(job).run { |scenario| ... }
# Simulation.new(job).permutations
# Simulation.new(job).variants
# Simulation.new(job).scenarios
module ChaoticJob
  class Simulation
    def initialize(job, depth: 1, variations: 100, test: nil, seed: nil)
      @template = job
      @depth = depth
      @variations = variations
      @test = test
      @seed = seed || Random.new_seed
      @random = Random.new(@seed)
    end

    def run(&callback)
      @template.class.retry_on RetryableError, attempts: @depth + 2, wait: 1, jitter: 0

      debug "👾 Running #{variants.size} simulations of the total #{permutations.size} possibilities..."

      scenarios.map do |scenario|
        run_scenario(scenario, &callback)
        print "·"
      end
    end

    def permutations
      callstack = capture_callstack.to_a
      error_locations = callstack.each_cons(2).flat_map do |left, right|
        lpath, lno = left
        rpath, rno = right
        key = "#{lpath}:#{lno}"
        # inject an error before and after each non-adjacent line
        if lpath == rpath && rno == lno + 1
          [[:before, key]]
        else
          [[:before, key], [:after, key]]
        end
      end
      final_key = callstack.last.join(":")
      error_locations.push [:before, final_key], [:after, final_key]
      error_locations.permutation(@depth)
    end

    def variants
      return permutations if @variations.nil?

      permutations.to_a.sample(@variations, random: @random)
    end

    def scenarios
      variants.map do |glitches|
        job = clone_job_template
        scenario = Scenario.new(job, glitches: glitches)
        job.job_id = scenario.to_s
        scenario
      end
    end

    private

    def capture_callstack
      return @callstack if defined?(@callstack)

      @callstack = Set.new
      job_class = @template.class
      job_file_path = job_class.instance_method(:perform).source_location&.first

      trace = TracePoint.new(:line) do |tp|
        next if tp.defined_class == self.class
        next unless tp.path == job_file_path ||
          tp.defined_class == job_class

        @callstack << [tp.path, tp.lineno]
      end

      trace.enable { @template.dup.perform_now }
      @template.class.queue_adapter.enqueued_jobs = []
      @callstack
    end

    def run_scenario(scenario, &callback)
      debug "👾 Running simulation with scenario: #{scenario}"
      @test.before_setup
      @test.simulation_scenario = scenario.to_s
      scenario.run
      @test.after_teardown
      callback.call(scenario)
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
