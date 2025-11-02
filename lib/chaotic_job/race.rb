# frozen_string_literal: true

# Race.new(jobs).run { |scenario| ... }
# Race.new(jobs).success?

module ChaoticJob
  class Race
    EVENT = :event_occurred

    attr_reader :executions

    def initialize(jobs, pattern, capture: nil)
      @jobs = jobs
      @pattern = pattern
      @capture = capture
      @executions = []
      @traces = []
      @fibers = {}
      @events = []
    end

    def run
      @jobs.each { |job| @fibers[job.class] = traced_fiber_for(job) }
      fibers = @fibers

      ActiveSupport::Notifications.subscribed(->(*args) { @events << ActiveSupportEvent.new(*args) }, @capture) do
        @pattern.each do |klass, _type, _key|
          fiber = fibers[klass]

          break unless fiber.alive?

          result = fiber.resume

          break unless result == EVENT
        end
      end

      # Clean up to prevent FiberError when accessing job methods later
      cleanup_traces
      cleanup_fibers

      self
    end

    def success?
      @executions == @pattern
    end

    def pattern_keys
      @pattern.map { |_, _, key| key }
    end

    private

    def traced_fiber_for(job)
      Fiber.new do
        tracer = Tracer.new(
          tracing: job.class,
          stack: @executions,
          effect: -> { Fiber.yield EVENT }
        )
        @traces << tracer
        tracer.capture { job.perform }
      end
    end

    def cleanup_traces
      @traces.each(&:disable)
      @traces.clear
    end

    def cleanup_fibers
      @fibers.values.each(&:kill)
      @fibers.clear
    end
  end
end
