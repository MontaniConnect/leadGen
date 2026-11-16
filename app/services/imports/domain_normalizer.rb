require "uri"

module Imports
  # "https://www.Acme.com/about" -> "acme.com"
  class DomainNormalizer
    def self.call(url)
      raw = url.to_s.strip.downcase
      return nil if raw.empty?

      host = URI.parse(raw.include?("://") ? raw : "http://#{raw}").host
      host&.sub(/\Awww\./, "").presence
    rescue URI::InvalidURIError
      nil
    end
  end
end
