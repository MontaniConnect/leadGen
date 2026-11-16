module Scoring
  # Where the Anthropic API key comes from: the ANTHROPIC_API_KEY environment variable, else Rails credentials.
  # `lookup` can be replaced (tests do) to simulate a missing or present key.
  module ApiKey
    class << self
      attr_writer :lookup

      def lookup = @lookup ||= method(:read)
      def value = lookup.call
      def present? = value.present?

      def read(env: ENV, credentials: Rails.application.credentials)
        env["ANTHROPIC_API_KEY"].presence || credentials.dig(:anthropic, :api_key).presence
      end
    end
  end
end
