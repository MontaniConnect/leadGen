module Outreach
  # What a person has approved on the Results page. Nothing here is ever set automatically.
  #  - approved defaults: { "tier:Hot" => "curious_question" } the variant to favour for a segment
  #  - approved example sends: past messages that may be shown to the drafting model as style examples
  class Approvals
    DEFAULTS_KEY = "learning.approved_defaults".freeze
    EXAMPLES_KEY = "learning.approved_example_ids".freeze

    def defaults = Setting.get(DEFAULTS_KEY) || {}
    def example_ids = Array(Setting.get(EXAMPLES_KEY)).map(&:to_i)

    # The approved variant for the first matching segment, most specific dimension first.
    def default_for(segments)
      Segments::PRECEDENCE.each do |dimension|
        variant = defaults["#{dimension}:#{segments[dimension]}"]
        return variant if variant
      end
      nil
    end

    def approve_default!(dimension, segment, variant)
      Setting.set(DEFAULTS_KEY, defaults.merge("#{dimension}:#{segment}" => variant))
    end

    def revoke_default!(key)
      Setting.set(DEFAULTS_KEY, defaults.except(key))
    end

    def approve_example!(send_id)
      Setting.set(EXAMPLES_KEY, (example_ids + [ send_id.to_i ]).uniq)
    end

    def revoke_example!(send_id)
      Setting.set(EXAMPLES_KEY, example_ids - [ send_id.to_i ])
    end
  end
end
