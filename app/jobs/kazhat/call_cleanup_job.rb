module Kazhat
  class CallCleanupJob < ApplicationJob
    queue_as :default

    def perform
      # End calls that have been active for more than 8 hours (likely stale)
      Call.where(status: "active")
          .where("started_at < ?", 8.hours.ago)
          .find_each(&:end_call!)

      # Mark ringing calls as missed after timeout
      Call.where(status: "ringing")
          .where("created_at < ?", Kazhat.configuration.call_timeout.seconds.ago)
          .find_each(&:mark_as_missed!)
    end
  end
end
