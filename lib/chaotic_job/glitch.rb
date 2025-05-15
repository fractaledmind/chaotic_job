# frozen_string_literal: true

# Glitch.new.before("job_crucible.rb:10") { do_anything }
# Glitch.new.before("Model#method", String, name: "Joel") { do_anything }
# Glitch.new.after("job_crucible.rb:11") { do_anything }
# Glitch.new.inject! { execute code to glitch }

module ChaoticJob
  class Glitch
    def initialize
      @breakpoints = {}
    end

    def before(key, ...)
      set_breakpoint(key, :before, ...)
      self
    end

    def after(key, ...)
      set_breakpoint(key, :after, ...)
      self
    end

    def inject!
      prev_key = nil
      prev_params = nil
      trace = TracePoint.new(:line, :call) do |tp|
        key, params = nil

        case tp.event
        when :line
          key = "#{tp.path}:#{tp.lineno}"
        when :call
          key = if Module === tp.self
            "#{tp.self}.#{tp.method_id}"
          else
            "#{tp.defined_class}##{tp.method_id}"
          end
          params = tp.parameters.map do |type, name|
            value = begin
              tp.binding.local_variable_get(name)
            rescue NameError
              nil
            end
            [type, name, value]
          end
        end

        begin
          execute_block(@breakpoints[prev_key][:after]) if @breakpoints.key?(prev_key) && matches?(@breakpoints[prev_key][:after], prev_params)

          execute_block(@breakpoints[key][:before]) if @breakpoints.key?(key) && matches?(@breakpoints[key][:before], params)
        ensure
          prev_key = key
          prev_params = params
        end
      end

      trace.enable
      yield if block_given?
    ensure
      trace.disable
      execute_block(@breakpoints[prev_key][:after]) if @breakpoints.key?(prev_key) && matches?(@breakpoints[prev_key][:after], prev_params)
    end

    def matches?(defn, params)
      return true if defn.nil?
      return true if params.nil?
      return true if defn[:args].empty?

      args = []
      kwargs = {}

      params.each do |kind, name, value|
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
        end
      end

      defn[:args].each_with_index do |type, index|
        return false unless type === args[index]
      end

      defn[:kwargs].each do |key, type|
        return false unless type === kwargs[key]
      end

      true
    end

    def all_executed?
      @breakpoints.all? do |_location, handlers|
        handlers.all? { |_position, handler| handler[:executed] }
      end
    end

    # def inspect
    #   @breakpoints.flat_map do |location, configs|
    #     configs.keys.map { |position| "#{position}-#{location}" }
    #   end.join("|>")
    # end

    private

    def set_breakpoint(key, position, *args, **kwargs, &block)
      @breakpoints[key] ||= {}
      @breakpoints[key][position] = {args: args, kwargs: kwargs, block: block, executed: false}
    end

    def execute_block(handler)
      return unless handler
      return if handler[:executed]

      handler[:executed] = true
      handler[:block].call
    end
  end
end
