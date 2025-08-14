# frozen_string_literal: true

require "spec_helper"

RSpec.describe ChaoticJob::Simulation do
  describe "#initialize" do
    it "works with only job passed" do
      simulation = described_class.new(TestJob.new)

      stack = simulation.callstack.to_a
      expect(stack[0]).to eq([:call, "TestJob#perform"])
      expect(stack[1][0]).to eq(:line)
      expect(stack[1][1]).to match(%r{chaotic_job/spec/spec_helper.rb:23})
      expect(stack[2][0]).to eq(:line)
      expect(stack[2][1]).to match(%r{chaotic_job/spec/spec_helper.rb:25})
      expect(stack[3]).to eq([:return, "TestJob#perform"])

      expect(simulation.tracing).to eq([TestJob])
    end

    it "raises when initialized with invalid callstack" do
      expect {
        described_class.new(TestJob.new, callstack: [])
      }.to raise_error(ChaoticJob::Error, "callstack must be a generated via ChaoticJob::Tracer")
    end

    it "works with job and callstack passed" do
      event = [:call, "#{TestJob.name}#perform"]
      callstack = ChaoticJob::Stack.new([event])
      simulation = described_class.new(TestJob.new, callstack: callstack)

      expect(simulation.callstack.to_a).to eq([event])
      expect(simulation.tracing).to eq([TestJob])
    end

    it "works with job and tracing passed" do
      tracing = [TestJob, ChaoticJob]
      simulation = described_class.new(TestJob.new, tracing: tracing)

      stack = simulation.callstack.to_a
      expect(stack[0]).to eq([:call, "TestJob#perform"])
      expect(stack[1][0]).to eq(:line)
      expect(stack[1][1]).to match(%r{chaotic_job/spec/spec_helper.rb:23})
      expect(stack[2][0]).to eq(:line)
      expect(stack[2][1]).to match(%r{chaotic_job/spec/spec_helper.rb:25})
      expect(stack[3]).to eq([:return, "TestJob#perform"])

      expect(simulation.tracing).to eq(tracing)
    end
  end

  describe "#define" do
    it "creates scenario methods for RSpec context" do
      job = TestJob.new
      event = [:call, "#{TestJob.name}#perform"]
      callstack = ChaoticJob::Stack.new([event])

      # Create a mock RSpec example group to test the define method
      test_class = Class.new do
        def self.it(name, &block)
          define_method("test_#{name.gsub(/[^a-zA-Z0-9_]/, '_')}", &block)
        end
      end

      simulation = described_class.new(job, callstack: callstack, test: test_class)

      # Initially no test methods should exist
      initial_methods = test_class.instance_methods.grep(/^test_/)
      expect(initial_methods.size).to eq(0)

      simulation.define { nil }

      # After define is called, there should be test methods created
      test_methods = test_class.instance_methods.grep(/^test_/)
      expect(test_methods.size).to eq(1)
      expect(test_methods.first.to_s).to match(/test_simulation_scenario_before_call_TestJob/)
    end
  end
end