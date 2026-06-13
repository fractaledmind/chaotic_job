# frozen_string_literal: true

# Scenario.new(job_or_workload, glitch:).run { |scenario| ... }
# Scenario.new(job_or_workload, glitch:).success?

module ChaoticJob
  class Scenario
    attr_reader :events, :glitch, :workload

    def initialize(subject, glitch:, raise: RetryableError, capture: nil)
      @workload = Workload.coerce(subject)
      @glitch = (Glitch === glitch) ? glitch : (raise Error.new("glitch: must be a Glitch instance, but got #{glitch.inspect}"))
      @raise = binding.local_variable_get(:raise)
      @capture = capture
      @events = []
    end

    # Backwards compatibility: callers reading `scenario.job` from the days
    # when Scenario only wrapped Active Jobs continue to work; non-job
    # workloads return nil here and use `#workload` instead.
    def job
      @workload.respond_to?(:job) ? @workload.job : nil
    end

    def run(&block)
      @glitch.set_action { raise @raise }

      ActiveSupport::Notifications.subscribed(->(*args) { @events << ActiveSupportEvent.new(*args) }, @capture) do
        @glitch.inject! do
          @workload.setup!
          if block
            block.call
          else
            @workload.drain!
          end
        end
      rescue *Array(@raise)
        # The glitch's configured error is the EXPECTED chaos outcome;
        # post-glitch assertions need to run on the aftermath. Active Job
        # workloads swallow this via retry_on before it escapes
        # @glitch.inject! — block workloads have no equivalent, so the
        # rescue is needed for the simulation cycle to complete uniformly.
      end

      self
    end

    def success?
      @glitch.executed?
    end

    # Alias for parity with the RSpec matcher path (`expect(scenario).to be_glitched`).
    alias_method :glitched?, :success?

    def before_line?(key)
      return false unless :line == @glitch.event

      key == @glitch.key
    end

    def before_call?(key)
      return false unless :call == @glitch.event

      key == @glitch.key
    end

    def before_return?(key)
      return false unless :return == @glitch.event

      key == @glitch.key
    end

    def to_s
      # ChaoticJob::Scenario(
      #   job: Job(arguments),   <-- or block: ..., depending on workload
      #   glitch: Glitch()
      # )
      buffer = +"ChaoticJob::Scenario(\n"

      @workload.describe(buffer)

      glitch_start, *glitch_lines = @glitch.to_s.split("\n")
      buffer << "  glitch: #{glitch_start}\n"
      glitch_lines.each do |line|
        buffer << "  #{line}\n"
      end
      buffer << "  events: [\n"
      @events.sort_by { |it| it.started }.each do |it|
        buffer << "    #{it.started.utc.iso8601(6)}: #{it.name}\n"
      end
      buffer << "  ]\n"
      buffer << ")"

      buffer
    end
  end
end
