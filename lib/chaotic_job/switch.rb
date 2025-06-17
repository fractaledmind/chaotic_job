# frozen_string_literal: true

module ChaoticJob
  module Switch
    extend self

    def on?
      @value ||= false
      true == @value
    end

    def off?
      @value ||= false
      false == @value
    end

    def on!
      @value = true
    end

    def off!
      @value = false
    end
  end
end
