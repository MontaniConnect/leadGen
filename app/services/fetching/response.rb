module Fetching
  # What an HTTP GET returned; error is :timeout or :network when there was no response.
  Response = Data.define(:status, :body, :url, :content_type, :error)
end
