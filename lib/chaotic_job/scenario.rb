# frozen_string_literal: true

# Scenario.new(job).run { |scenario| ... }
# Scenario.new(job).all_glitched?

module ChaoticJob
  class Scenario
    attr_reader :events, :glitch, :job

    def initialize(job, glitch:, raise: RetryableError, capture: /active_job/)
      @job = job
      @glitch = (Glitch === glitch) ? glitch : (raise Error.new("glitch: must be a Glitch instance, but got #{glitch.inspect}"))
      @raise = binding.local_variable_get(:raise)
      @capture = capture
      @events = []
    end

    def run(&block)
      @job.class.retry_on RetryableError, attempts: 10, wait: 1, jitter: 0
      @glitch.set_action { raise @raise }

      ActiveSupport::Notifications.subscribed(->(event) { @events << event.dup }, @capture) do
        @glitch.inject! do
          @job.enqueue
          if block
            block.call
          else
            Performer.perform_all
          end
        end
      end

      self
    end

    def glitched?
      @glitch.executed?
    end

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
      #   job: Job(arguments),
      #   glitch: Glitch()
      # )
      buffer = +"ChaoticJob::Scenario(\n"

      job_attributes = @job.serialize
      buffer << "  job: #{job_attributes["job_class"]}"
      buffer << "("
      buffer << job_attributes["arguments"].join(", ")
      buffer << "),\n"

      glitch_start, *glitch_lines = @glitch.to_s.split("\n")
      buffer << "  glitch: #{glitch_start}\n"
      glitch_lines.each do |line|
        buffer << "  #{line}\n"
      end
      buffer << ")"

      buffer
    end
  end
end
