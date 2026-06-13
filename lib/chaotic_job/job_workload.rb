# frozen_string_literal: true

# Active Job-shaped Workload — preserves chaotic_job's original behavior:
# install retry_on for the gem's RetryableError, enqueue the job, drain
# the queue via Performer.

module ChaoticJob
  class JobWorkload < Workload
    attr_reader :job

    def initialize(job, raise_on: RetryableError, retry_attempts: 10)
      unless defined?(ActiveJob::Base) && job.is_a?(ActiveJob::Base)
        raise Error.new("JobWorkload requires an ActiveJob, got #{job.inspect}")
      end

      @job = job
      @raise_on = raise_on
      @retry_attempts = retry_attempts
    end

    def setup!
      @job.class.retry_on @raise_on, attempts: @retry_attempts, wait: 1, jitter: 0
      @job.enqueue
    end

    def drain!
      Performer.perform_all
    end

    # Drain only jobs scheduled before `cutoff` — Simulation's
    # `perform_only_jobs_within` option drives this.
    def perform_within(cutoff)
      Performer.perform_all_before(cutoff)
    end

    def tracing
      [@job.class]
    end

    def clone_for_variant
      serialized = @job.serialize
      cloned = ActiveJob::Base.deserialize(serialized)
      cloned.exception_executions = {}
      JobWorkload.new(cloned, raise_on: @raise_on, retry_attempts: @retry_attempts)
    end

    # Stamp a variant identifier into the job_id so debugging output names
    # the glitch that produced this run. Simulation calls this after
    # cloning.
    def tag_variant!(glitch)
      @job.job_id = [@job.job_id.split("-").first, glitch.event, glitch.key].join("-")
      self
    end

    def identity
      attrs = @job.serialize
      "#{attrs["job_class"]}(#{attrs["arguments"].join(", ")})"
    end

    def describe(buffer)
      attrs = @job.serialize
      buffer << "  job: #{attrs["job_class"]}"
      buffer << "("
      buffer << attrs["arguments"].join(", ")
      buffer << "),\n"
    end
  end
end
