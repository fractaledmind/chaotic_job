# frozen_string_literal: true

# A `Workload` is the unit of work Scenario and Simulation drive under
# chaos — an Active Job, an arbitrary callable, or anything else that
# satisfies the protocol.
#
# Two implementations ship:
#
#   ChaoticJob::JobWorkload.new(active_job)
#   ChaoticJob::BlockWorkload.new(tracing: [Klass, ...], label: "...") { ... }
#
# Scenario.new / Simulation.new accept a Workload, a bare Active Job
# (auto-wrapped for backwards compatibility), or a block + tracing list.

module ChaoticJob
  # Base protocol. Subclasses implement #setup!, #drain!, #tracing,
  # #clone_for_variant, #identity, and #describe.
  class Workload
    # Coerce a job-or-workload into a Workload. Used by Scenario/Simulation
    # constructors to preserve their existing positional-Active-Job APIs.
    def self.coerce(subject)
      case subject
      when Workload then subject
      else
        if defined?(ActiveJob::Base) && subject.is_a?(ActiveJob::Base)
          JobWorkload.new(subject)
        else
          raise Error.new("expected Workload or ActiveJob, got #{subject.inspect}")
        end
      end
    end

    # Run any one-time setup that must happen INSIDE the glitched region but
    # BEFORE the user's drain block (e.g. Active Job's `enqueue`). Default:
    # no-op.
    def setup!
    end

    # Execute the workload to completion. For a job, this drains the queue.
    # For a block, this calls it.
    def drain!
      raise NotImplementedError
    end

    # Convenience: setup + drain. Used when no user-supplied drain block.
    def perform!
      setup!
      drain!
    end

    # Default modules for Tracer to instrument when none are specified.
    def tracing
      raise NotImplementedError
    end

    # Return a fresh, independent copy of this workload — Simulation uses one
    # per scenario. For stateless workloads (blocks) it's fine to return
    # `self`; for mutable ones (jobs carrying execution state) deep-clone.
    def clone_for_variant
      raise NotImplementedError
    end

    # Short string suitable for test-method names, journal logs, and
    # debugging output.
    def identity
      raise NotImplementedError
    end

    # Append a human-readable description into the given buffer. Called from
    # Scenario#to_s; should produce indented lines.
    def describe(buffer)
      buffer << "  workload: #{identity}\n"
    end

    # Run-once-with-a-deadline hook. Optional — only JobWorkload implements
    # it (it's how Simulation's `perform_only_jobs_within` time-boxes job
    # execution). Workloads that don't expose a notion of "scheduled work"
    # leave this undefined.

    # Race-fiber execution: run the work synchronously, no queue or
    # orchestration involved. Race traces this call and routes events by
    # #tracer_owner. JobWorkload invokes job.perform directly (not the
    # queue drain); BlockWorkload invokes the block.
    def call
      raise NotImplementedError
    end

    # Identity used to route Race events back to this workload's fiber.
    # Must be stable across capture (Relay) and execution (Race) for the
    # same workload. Strings, symbols, classes are all fine — distinctness
    # is the only contract. Two workloads sharing an owner collide; Race
    # will overwrite the earlier fiber with the later one.
    def tracer_owner
      raise NotImplementedError
    end
  end
end
