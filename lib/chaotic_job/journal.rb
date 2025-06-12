# frozen_string_literal: true

# Journal.log
# Journal.log(thing, scope: :special)
# Journal.total
# Journal.total(scope: :special)
# Journal.all

module ChaoticJob
  module Journal
    extend self

    DEFAULT = Object.new.freeze

    def reset!
      @logs = {}
    end

    def log(item = DEFAULT, scope: :default)
      @logs ||= {}
      @logs[scope] ||= Set.new
      set = @logs[scope].to_set
      if item != DEFAULT
        set << item
      else
        max = set.to_a.max || 0
        set << max + 1
      end
      item
    end

    def push(item = true, scope: :default)
      @logs ||= {}
      @logs[scope] ||= []
      array = @logs[scope].to_a
      array << item
      item
    end

    def size(scope: :default)
      @logs[scope]&.size || 0
    end

    def entries(scope: :default)
      @logs[scope]&.to_a
    end

    def top(scope: :default)
      entries(scope: scope)&.first
    end
  end
end
