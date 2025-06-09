# frozen_string_literal: true

require "active_job"

module ChaoticJob
  module Performer
    extend ActiveJob::TestHelper
    extend self

    def perform_all
      until (jobs = enqueued_jobs_where).empty?
        perform(jobs)
      end
    end

    def perform_all_before(cutoff)
      time = resolve_cutoff(cutoff)

      until (jobs = enqueued_jobs_where(before: time)).empty?
        perform(jobs)
      end
    end
    alias_method :perform_all_within, :perform_all_before

    def perform_all_after(cutoff)
      time = resolve_cutoff(cutoff)

      until (jobs = enqueued_jobs_where(after: time)).empty?
        perform(jobs)
      end
    end

    def perform(jobs)
      jobs.each do |payload|
        queue_adapter.enqueued_jobs.delete(payload)
        queue_adapter.performed_jobs << payload
        instantiate_job(payload, skip_deserialize_arguments: true).perform_now
      end.count
    end

    def enqueued_jobs_where(before: nil, after: nil)
      enqueued_jobs
        .sort do |ljob, rjob|
          lat = ljob[:at]
          rat = rjob[:at]

          # sort by scheduled time, with nil values first
          if lat && rat
            lat <=> rat
          else
            lat ? 1 : -1
          end
        end
        .select do |job|
          scheduled_at = job[:at]

          next true if scheduled_at.nil?

          # Skip if the job is scheduled after the cutoff time
          if before
            next false if scheduled_at > before.to_f
          end

          # Skip if the job is scheduled before the cutoff time
          if after
            next false if scheduled_at < after.to_f
          end

          true
        end
    end

    def resolve_cutoff(cutoff)
      time = case cutoff
      in ActiveSupport::Duration
        cutoff.from_now
      in Time
        cutoff
      else
        raise Error.new("cutoff must be Time or ActiveSupport::Duration, but got #{cutoff.inspect}")
      end
      delta = (Time.now - time).abs.floor

      changeset = case delta
      when 0..59                    # seconds
        {usec: 0}
      when 60..3599                 # minutes
        {sec: 0, usec: 0}
      when 3600..86_399             # hours
        {min: 0, sec: 0, usec: 0}
      else  # days+
        {hour: 0, min: 0, sec: 0, usec: 0}
      end
      time.change(**changeset)
    end
  end
end
