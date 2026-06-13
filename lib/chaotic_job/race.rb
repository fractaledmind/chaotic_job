# frozen_string_literal: true

# Race.new(jobs).run { |scenario| ... }
# Race.new(jobs).success?

module ChaoticJob
  class Race
    EVENT = :event_occurred

    attr_reader :executions

    # `racers` accepts ActiveJob instances (auto-wrapped as JobWorkloads)
    # or Workloads directly. Each racer is keyed by its #tracer_owner in
    # the fibers hash; schedule events route to fibers via that owner. Two
    # racers sharing an owner overwrite each other — distinctness is the
    # caller's contract.
    def initialize(racers, schedule:, capture: nil)
      @workloads = Array(racers).map { |racer| Workload.coerce(racer) }
      @schedule = schedule
      @capture = capture
      @executions = []
      @traces = []
      @fibers = {}
      @events = []
    end

    # Backwards-compat reader for users who reached into @jobs / .jobs.
    def jobs
      @workloads.map { |w| w.respond_to?(:job) ? w.job : w }
    end

    def run
      @workloads.each { |workload| @fibers[workload.tracer_owner] = traced_fiber_for(workload) }
      fibers = @fibers

      ActiveSupport::Notifications.subscribed(->(*args) { @events << ActiveSupportEvent.new(*args) }, @capture) do
        @schedule.each do |event|
          fiber = fibers[event.owner]

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
      @executions == @schedule
    end

    def to_s
      # ChaoticJob::Race(
      #   jobs: [
      #     Job(arguments),
      #     Job(arguments),
      #   ],
      #   schedule: [
      #     event: key
      #   ]
      # )
      buffer = +"ChaoticJob::Race(\n"

      buffer << "  racers: [\n"
      @workloads.each do |workload|
        line = +""
        workload.describe(line)
        buffer << line.strip.split("\n").map { |l| "    #{l.sub(/\A\s*\w+:\s*/, "")}" }.join("\n")
        buffer << "\n"
      end
      buffer << "  ]\n"

      buffer << "  schedule: [\n"
      @schedule.each do |_, event, key|
        buffer << "    #{event}: #{key}\n"
      end
      buffer << "  ]\n"
      buffer << ")"

      buffer
    end

    def schedule_keys
      @schedule.map { |it| "#{it.type}_#{it.key}" }
    end

    private

    def traced_fiber_for(workload)
      Fiber.new do
        tracer = Tracer.new(
          tracing: workload.tracing,
          owner: workload.tracer_owner,
          stack: @executions,
          effect: -> { Fiber.yield EVENT },
          fiber_local: true
        )
        @traces << tracer
        tracer.capture { workload.call }
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
