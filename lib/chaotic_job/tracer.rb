# frozen_string_literal: true

# Tracer.new(tracing: Job)
# Tracer.new { |tp| tp.path.start_with? "foo" }
# tracer.capture { job.perform }

module ChaoticJob
  class Tracer
    def initialize(tracing: nil, stack: Stack.new, effect: nil, returns: nil, owner: nil, fiber_local: false, &block)
      @constraint = block || Array(tracing)
      @stack = stack
      @effect = effect
      @owner = owner
      @returns = returns || @stack
      # TracePoints are GLOBAL; without scoping, fiber A's TP fires on
      # fiber B's code and records under A's owner. Race needs each fiber's
      # tracer to only see its own fiber's events. Snapshot Fiber.current
      # at construction time (Race creates its Tracer INSIDE the fiber).
      @fiber = fiber_local ? Fiber.current : nil
      @trace = prepare_trace
    end

    def capture(&block)
      @trace.enable(&block)

      @returns
    end

    def enable
      @trace.enable
    end

    def disable
      @trace.disable
    end

    private

    def prepare_trace
      constraint = @constraint
      this = self.class

      TracePoint.new(:line, :call, :return) do |tp|
        # :nocov: SimpleCov cannot track code executed _within_ a TracePoint
        next if @fiber && Fiber.current != @fiber
        next if tp.defined_class == this
        next unless (Array === constraint) ? constraint.include?(tp.defined_class) : constraint.call(tp)

        key = case tp.event
        when :line then line_key(tp)
        when :call, :return then call_key(tp)
        end
        # Owner identifies WHO produced this event; the Race driver routes
        # resumes by it. Defaults to the defined class (existing behavior;
        # job-shaped racers have disjoint classes). Workload-aware callers
        # pass workload.tracer_owner so block workloads sharing a class
        # still route distinctly.
        event = TracedEvent.new(@owner || tp.defined_class, tp.event, key)

        @stack << event
        @effect&.call
        # :nocov:
      end
    end

    # :nocov: SimpleCov cannot track code executed _within_ a TracePoint
    def line_key(event)
      "#{event.path}:#{event.lineno}"
    end

    def call_key(event)
      if Module === event.self
        "#{event.self}.#{event.method_id}"
      else
        "#{event.defined_class}##{event.method_id}"
      end
    end
    # :nocov:
  end
end
