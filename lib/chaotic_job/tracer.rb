# frozen_string_literal: true

# Tracer.new(tracing: Job)
# Tracer.new { |tp| tp.path.start_with? "foo" }
# tracer.capture { job.perform }

module ChaoticJob
  class Tracer
    def initialize(tracing: nil, stack: Stack.new, effect: nil, returns: nil, &block)
      @constraint = block || Array(tracing)
      @stack = stack
      @effect = effect
      @returns = returns || @stack
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
        next if tp.defined_class == this
        next unless (Array === constraint) ? constraint.include?(tp.defined_class) : constraint.call(tp)

        key = case tp.event
        when :line then line_key(tp)
        when :call, :return then call_key(tp)
        end
        event = TracedEvent.new(tp.defined_class, tp.event, key)

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
