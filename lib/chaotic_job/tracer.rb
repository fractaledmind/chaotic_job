# frozen_string_literal: true

# Tracer.new { |tp| tp.path.start_with? "foo" }
# Tracer.new.capture { code_execution_to_trace_callstack }

module ChaoticJob
  class Tracer
    def initialize(&constraint)
      @constraint = constraint
      @callstack = Set.new
    end

    def capture(&block)
      trace = TracePoint.new(:line, :call) do |tp|
        next if tp.defined_class == self.class
        next unless @constraint.call(tp)

        case tp.event
        when :line
          key = line_key(tp)
        when :call
          key = call_key(tp)
        end

        @callstack << [key, tp.path, tp.lineno]
      end

      trace.enable(&block)
      @callstack.to_a
    end

    private

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
  end
end
