# frozen_string_literal: true

# Glitch.before_line("job_crucible.rb:10") { do_anything }
# Glitch.before_call("Model#method", String, name: "Joel") { do_anything }
# Glitch.before_return("Model#method", String, name: "Joel") { do_anything }
# Glitch.inject! { execute code to glitch }

module ChaoticJob
  class Glitch
    def self.before_line(key, &block)
      new(key, :line, &block)
    end

    def self.before_call(key, *args, **kwargs, &block)
      new(key, :call, *args, **kwargs, &block)
    end

    def self.before_return(key, return_type = nil, &block)
      new(key, :return, retval: return_type, &block)
    end

    attr_reader :key, :event

    def initialize(key, event, *args, retval: nil, **kwargs, &block)
      @event = event
      @key = key
      @args = args
      @retval = retval
      @kwargs = kwargs
      @block = block
      @executed = false
    end

    def set_action(force: false, &block)
      @block = block if @block.nil? || force
    end

    def inject!(&block)
      trace = TracePoint.new(@event) do |tp|
        # :nocov: SimpleCov cannot track code executed _within_ a TracePoint
        key = derive_key(tp)
        next unless @key == key

        matchers = derive_matchers(tp)
        next unless matches?(matchers)

        execute_block
        # :nocov:
      end

      trace.enable(&block)
    end

    def executed?
      @executed
    end

    def to_s
      # ChaoticJob::Glitch(
      #   event: String,
      #   key: String,
      #   args: [Array],
      #   kwargs: [Hash],
      #   retval: [Object]
      # )
      buffer = +"ChaoticJob::Glitch(\n"
      buffer << "  event: #{@event}\n"
      buffer << "  key: #{@key}\n"
      buffer << "  args: #{@args}\n" if @args.any?
      buffer << "  kwargs: #{@kwargs}\n" if @kwargs.any?
      buffer << "  retval: #{@retval}\n" if @retval
      buffer << ")"

      buffer
    end

    private

    # :nocov: SimpleCov cannot track code executed _within_ a TracePoint
    def matches?(matchers)
      return true if matchers.nil?
      return true if @args.empty? && @kwargs.empty? && @retval.nil?

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

      @args.each_with_index do |type, index|
        return false unless type === args[index]
      end

      @kwargs.each do |key, type|
        return false unless type === kwargs[key]
      end

      return false unless @retval === retval

      true
    end

    def execute_block
      return if @executed

      @executed = true
      @block.call
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
