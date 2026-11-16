module Fetching
  # One fetched URL: status ("ok", "blocked", "not_found", "timeout", "error") and the HTML when ok.
  FetchedPage = Data.define(:status, :http_status, :html, :url)
end
