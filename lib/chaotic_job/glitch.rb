# frozen_string_literal: true

# Glitch.before_line("job_crucible.rb:10") { do_anything }
# Glitch.before_call("Model#method", String, name: "Joel") { do_anything }
# Glitch.before_return("Model#method", String, name: "Joel") { do_anything }
# Glitch.inject! { execute code to glitch }

module ChaoticJob
  class Glitch
    def self.before_line(key, &block)
      new.before_line(key, &block)
    end

    def self.before_call(key, ...)
      new.before_call(key, ...)
    end

    def self.before_return(key, return_type = nil, &block)
      new.before_return(key, return_type, &block)
    end

    def initialize
      @breakpoints = {}
    end

    def before_line(key, &block)
      set_breakpoint(key, :line, &block)
      self
    end

    def before_call(key, ...)
      set_breakpoint(key, :call, ...)
      self
    end

    def before_return(key, return_type = nil, &block)
      set_breakpoint(key, :return, retval: return_type, &block)
      self
    end

    def set_action(force: false, &block)
      @breakpoints.each do |_key, handlers|
        handlers.each do |_event, handler|
          handler[:block] = block if handler[:block].nil? || force
        end
      end
      self
    end

    def inject!(&block)
      breakpoints = @breakpoints

      trace = TracePoint.new(:line, :call, :return) do |tp|
        # :nocov: SimpleCov cannot track code executed _within_ a TracePoint
        key = derive_key(tp)
        matchers = derive_matchers(tp)

        next unless (defn = breakpoints.dig(key, tp.event))
        next unless matches?(defn, matchers)

        execute_block(defn)
        # :nocov:
      end

      trace.enable(&block)
    end

    def all_executed?
      @breakpoints.all? do |_key, handlers|
        handlers.all? { |_event, handler| handler[:executed] }
      end
    end

    private

    def set_breakpoint(key, event, *args, retval: nil, **kwargs, &block)
      @breakpoints[key] ||= {}
      @breakpoints[key][event] = {args: args, kwargs: kwargs, retval: retval, block: block, executed: false}
    end

    # :nocov: SimpleCov cannot track code executed _within_ a TracePoint
    def matches?(defn, matchers)
      return true if defn.nil?
      return true if matchers.nil?
      return true if defn[:args].empty? && defn[:kwargs].empty? && defn[:retval].nil?

      args = []
      kwargs = {}
      retval = nil

      matchers.each do |kind, name, value|
        case kind
        when :req
          args << value
        when :opt
          args << value if value
        when :rest
          args.concat(value) if value
        when :keyreq
          kwargs[name] = value
        when :key
          kwargs[name] = value
        when :keyrest
          kwargs.merge!(value) if value
        when :retval
          retval = value
        end
      end

      defn[:args].each_with_index do |type, index|
        return false unless type === args[index]
      end

      defn[:kwargs].each do |key, type|
        return false unless type === kwargs[key]
      end

      return false unless defn[:retval] === retval

      true
    end

    def execute_block(handler)
      return unless handler
      return if handler[:executed]

      handler[:executed] = true
      handler[:block].call
    end

    def derive_key(trace)
      case trace.event
      when :line
        "#{trace.path}:#{trace.lineno}"
      when :call, :return
        if Module === trace.self
          "#{trace.self}.#{trace.method_id}"
        else
          "#{trace.defined_class}##{trace.method_id}"
        end
      end
    end

    def derive_matchers(trace)
      case trace.event
      when :line
        nil
      when :call
        trace.parameters.map do |type, name|
          value = trace.binding.local_variable_get(name) rescue nil # standard:disable Style/RescueModifier
          [type, name, value]
        end
      when :return
        [[:retval, nil, trace.return_value]]
      end
    end
    # :nocov:
  end
end
