# frozen_string_literal: true

# Relay.new(jobs).define { |race| assert something }

module ChaoticJob
  class Relay
    attr_reader :sample

    def initialize(*jobs, tracing: nil, sample: 10, test: nil, seed: nil)
      @jobs = jobs
      @tracing = tracing
      @callstacks = nil
      @possibilities = nil
      @sample = sample
      @test = test
      @seed = seed || Random.new_seed
      @random = Random.new(@seed)
    end

    def define(&assertions)
      @callstacks = capture_callstacks
      @possibilities = total_race_patterns(@callstacks.map(&:size))
      @sample = @sample.clamp(1, @possibilities)

      debug "👾 Defining #{@sample} race conditions of the total #{@possibilities} possibilities..."

      races.each do |race|
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
        race.run
        instance_exec(race, &assertions)

        expect(race).to be_success, "Race did not follow pattern: #{race.pattern}"
      end
    end

    def define_minitest_test_for(race, &assertions)
      test_method_name = "test_race_pattern_#{race.pattern_keys.join("_")}"

      @test.define_method(test_method_name) do
        race.run
        instance_exec(race, &assertions)

        assert race.success?, "Race did not follow pattern: #{race.pattern}"
      end
    end

    def races
      lengths = @callstacks.map(&:length)
      samples = Set.new.tap do |set|
        until set.size == @sample
          runs = generate_runs(lengths)
          set << interleave_runs(runs, @callstacks)
        end
      end

      samples.map do |pattern|
        Race.new(@jobs, pattern: pattern)
      end
    end

    def generate_runs(stack_sizes)
      # Input: `stack_sizes` is an array of integers
      #   Array has same size as @jobs and denotes the respective sizes of each's callstack.
      #   => [7, 5, 8]

      # Step 1: Determine how many runs we will split each callstack into.
      #   We randomly choose a number from 1 to half the size of the callstack (rounding down),
      #   because this prevents each callstack from having too many runs and thus keeps runs manageable.
      #   => [2, 1, 3]
      runs_per_job = stack_sizes.map { |len| @random.rand(2..(len / 2)) }

      # Step 2: Determine the run length of each callstack's runs.
      #   We randomly choose where to split each callstack to build the N runs for that callstack,
      #   then we compute the length of each run such that the sum of all runs for a callstack
      #   equals the size of that callstack (making the runs exhaustive).
      #   => [[3, 4], [5], [2, 4, 2]]
      stack_sizes.each_with_index do |stack_size, array_idx|
        runs = runs_per_job[array_idx]

        if runs == 1
          # When the callstack needs only 1 run, the size of that run is the length of the stack.
          runs_per_job[array_idx] = [stack_size]
        else
          # When the callstack needs N runs, randomly choose N-1 split points,
          splits = (1...stack_size).to_a.sample([runs - 1, stack_size - 1].min, random: @random).sort
          # add the start and end,
          splits.prepend(0).append(stack_size)
          # then compute the length of each run
          runs_per_job[array_idx] = splits.each_cons(2).map { |a, b| b - a }
        end
      end

      # Step 3: Build array of tuples of each callstack's runs.
      #   For each callstack's collection of run lengths, add the callstack's index.
      #   => [[0, 3], [0, 4], [1, 5], [2, 2], [2, 4], [2, 2]]
      all_runs = []
      runs_per_job.each_with_index do |run_lengths, array_idx|
        run_lengths.each do |run_length|
          all_runs << [array_idx, run_length]
        end
      end

      # Step 4: Shuffle the tuples into a deterministically random order.
      #   => [[2, 2], [0, 4], [2, 4], [1, 5], [0, 3], [2, 2]]
      all_runs.shuffle(random: @random)
    end

    def interleave_runs(runs, callstacks)
      # Input: `runs` is an array of tuples, callstack index and run length
      #   => [[2, 2], [0, 4], [2, 4], [1, 5], [0, 3], [2, 2]]
      cursors = callstacks.map { 0 }

      [].tap do |interleaved|
        runs.each do |idx, len|
          stack = callstacks[idx]
          cursor = cursors[idx]
          interleaved.concat stack[cursor, len]
          cursors[idx] += len
        end
      end
    end

    def capture_callstacks
      tracing = @tracing
      @jobs.map do |job|
        tracer = Tracer.new(tracing: Array(tracing || job.class))
        stack = tracer.capture do
          job.enqueue
          # run the template job as well as any other jobs it may enqueue
          Performer.perform_all
        end
        stack.to_a
      end
    end

    def total_race_patterns(lengths)
      total = lengths.sum
      return 1 if total <= 1

      result = 1
      remaining = total

      lengths.each do |count|
        next if count == 0
        count.times do |i|
          result = result * (remaining - i) / (i + 1)
        end
        remaining -= count
      end

      result
    end

    def debug(...)
      @jobs.first.logger.debug(...)
    end
  end
end
