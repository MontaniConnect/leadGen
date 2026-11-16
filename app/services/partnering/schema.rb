module Partnering
  module Schema
    DEFINITION = LlmSchema.new(Rails.root.join("config/schemas/partner_draft.json"))

    def self.full = DEFINITION.full
    def self.for_api = DEFINITION.for_api
    def self.errors_for(data) = DEFINITION.errors_for(data)
  end
end
