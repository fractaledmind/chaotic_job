# frozen_string_literal: true

# Block-shaped Workload — drives chaos tests over any callable, not just
# Active Jobs. The block is the unit; the caller declares which modules
# Tracer should instrument.
#
#   workload = ChaoticJob::BlockWorkload.new(tracing: [PaymentService]) do
#     PaymentService.call(payment)
#   end
#
#   scenario = ChaoticJob::Scenario.new(workload, glitch:, raise: MyError)
#   scenario.run { perform_recovery_and_assert }
#
# A BlockWorkload is stateless from chaotic_job's perspective: Simulation
# can run many scenarios against the same instance because each scenario
# just re-invokes the block. The block's CLOSURE is the user's concern —
# capturing mutable state shared across variants is on them.

module ChaoticJob
  class BlockWorkload < Workload
    attr_reader :label

    def initialize(tracing:, label: nil, &block)
      raise Error.new("BlockWorkload requires a block") unless block

      @tracing = Array(tracing)
      raise Error.new("BlockWorkload requires `tracing:` — Tracer needs at least one module to instrument") if @tracing.empty?

      @block = block
      @label = label || derive_label(block)
    end

    def drain!
      @block.call
    end

    # Race executes the block directly inside its fiber. Same as drain!
    # because there is no queue layer to skip.
    def call
      @block.call
    end

    # Label as owner — distinct labels keep multiple block workloads
    # tracing the same module disambiguated in the schedule.
    def tracer_owner
      @label
    end

    attr_reader :tracing

    # The block is stateless from our side; returning self keeps closures
    # intact. If the user's closure captures mutable state and that state
    # bleeds across Simulation variants, the user can pass `clone:` (TODO)
    # or — pragmatically — write the block to reset its own state.
    def clone_for_variant
      self
    end

    def identity
      @label
    end

    def describe(buffer)
      buffer << "  block: #{@label}\n"
    end

    private

    def derive_label(block)
      loc = block.source_location
      loc ? "block@#{loc.join(":")}" : "block@unknown"
    end
  end
end
