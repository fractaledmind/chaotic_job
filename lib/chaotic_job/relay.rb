# frozen_string_literal: true

module ChaoticJob
  class Relay
    def initialize(jobs, variations: nil, test: nil, seed: nil)
      @jobs = jobs
      @variations = variations
      @test = test
      @seed = seed || Random.new_seed
      @random = Random.new(@seed)
    end

    def define(&assertions)
      callstacks = @jobs.map do |job|
        tracer = Tracer.new(tracing: job.class)
        stack = tracer.capture do
          job.enqueue
          # run the template job as well as any other jobs it may enqueue
          Performer.perform_all
        end
        stack.to_a
      end
      patterns = all_race_patterns(*callstacks)
      patterns.each do |pattern|
        race = Race.new(@jobs, pattern)
        define_test_for(race, &assertions)
      end
    end

    private

    def define_test_for(race, &assertions)
      if defined?(RSpec)
        define_rspec_test_for(race, &assertions)
      else
        define_minitest_test_for(race, &assertions)
      end
    end

    def define_rspec_test_for(race, &assertions)
      example_name = "test_race_pattern_#{race.pattern_keys.join("_")}"

      @test.it example_name do
        run_race(race, &assertions)

        expect(race).to be_success, "Race did not follow pattern: #{race.pattern}"
      end
    end

    def define_minitest_test_for(race, &assertions)
      test_method_name = "test_race_pattern_#{race.pattern_keys.join("_")}"

      @test.define_method(test_method_name) do
        run_race(race, &assertions)

        assert race.success?, "Race did not follow pattern: #{race.pattern}"
      end
    end

    def run_race(race, &assertions)
      race.run!
      instance_exec(race, &assertions)
    end

    def all_race_patterns(*sequences)
      sequences = sequences.reject(&:empty?)

      return [[]] if sequences.empty?
      return sequences if sequences.length == 1

      results = []

      # Try taking the first element from each sequence
      sequences.each_with_index do |seq, index|
        # Create remaining sequences with first element removed from current sequence
        remaining_sequences = sequences.map.with_index do |s, i|
          (i == index) ? s[1..] : s
        end

        # Get all interleavings of the remaining sequences
        rest_interleavings = all_race_patterns(*remaining_sequences)

        # Prepend the first element to each interleaving
        rest_interleavings.each do |interleaving|
          results << [seq[0]] + interleaving
        end
      end

      results
    end
  end
end
