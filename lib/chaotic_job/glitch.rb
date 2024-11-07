# frozen_string_literal: true

# Glitch.new.before("job_crucible.rb:10") { do_anything }
# Glitch.new.after("job_crucible.rb:11") { do_anything }
# Glitch.new.inject! { execute code to glitch }

module ChaoticJob
  class Glitch
    def initialize
      @breakpoints = {}
      @file_contents = {}
    end

    def before(path_with_line, &block)
      set_breakpoint(path_with_line, :before, &block)
    end

    def after(path_with_line, &block)
      set_breakpoint(path_with_line, :after, &block)
    end

    def inject!
      prev_key = nil
      trace = TracePoint.new(:line) do |tp|
        key = "#{tp.path}:#{tp.lineno}"
        # content = @file_contents[tp.path]
        # line = content[tp.lineno - 1]
        # next unless line.match? key

        begin
          execute_block(@breakpoints[prev_key][:after]) if prev_key && @breakpoints.key?(prev_key)

          execute_block(@breakpoints[key][:before]) if @breakpoints.key?(key)
        ensure
          prev_key = key
        end
      end

      trace.enable
      yield if block_given?
    ensure
      trace.disable
      execute_block(@breakpoints[prev_key][:after]) if prev_key && @breakpoints.key?(prev_key)
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

    def set_breakpoint(path_with_line, position, &block)
      @breakpoints[path_with_line] ||= {}
      # contents = File.read(file_path).split("\n") unless @file_contents.key?(path_with_line)
      # @file_contents << contents
      @breakpoints[path_with_line][position] = { block: block, executed: false }
    end

    def execute_block(handler)
      return unless handler
      return if handler[:executed]

      handler[:executed] = true
      handler[:block].call
    end
  end
end
