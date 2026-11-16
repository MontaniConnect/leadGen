module Scoring
  # One result from a Message Batch. status: "succeeded", "errored", "canceled" or "expired";
  # reply is set only when succeeded.
  BatchEntry = Data.define(:custom_id, :status, :reply, :error)
end
