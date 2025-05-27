# frozen_string_literal: true

# Journal.log
# Journal.log(thing, scope: :special)
# Journal.total
# Journal.total(scope: :special)
# Journal.all

module ChaoticJob
  module Journal
    extend self

    def reset!
      @logs = {}
    end

    def log(item = 1, scope: :default)
      @logs ||= {}
      @logs[scope] ||= []
      @logs[scope] << item
      item
    end

    def size(scope: :default)
      @logs[scope]&.size || 0
    end

    def entries(scope: :default)
      @logs[scope]
    end

    def top(scope: :default)
      entries(scope: scope)&.first
    end
  end
end
