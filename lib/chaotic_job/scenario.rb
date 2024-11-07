# frozen_string_literal: true

# Scenario.new(job).run { |scenario| ... }
# Scenario.new(job).all_glitched?

module ChaoticJob
  class Scenario
    attr_reader :events

    def initialize(job, glitches:, raise: RetryableError, capture: /active_job/)
      @job = job
      @glitches = glitches
      @raise = raise
      @capture = capture
      @glitch = nil
      @events = []
    end

    def run
      @job.class.retry_on RetryableError, attempts: 10, wait: 1, jitter: 0

      ActiveSupport::Notifications.subscribed(->(event) { @events << event.dup }, @capture) do
        glitch.inject! do
          if block_given?
            yield
          else
            @job.enqueue
            Performer.perform_all
          end
        end
      end

      # TODO: assert that all glitches ran
    end

    def to_s
      @glitches.map { |position, location| "#{position}-#{location}" }.join("|>")
    end

    def all_glitched?
      @glitch.all_executed?
    end

    private

    def glitch
      @glitch ||= Glitch.new.tap do |glitch|
        @glitches.each do |position, location, _description|
          glitch.public_send(position, location) { raise @raise }
        end
      end
    end
  end
end
