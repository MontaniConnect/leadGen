module Outreach
  # Chooses which drafted variant a new send will use.
  #  - Default: uniformly random among the variants this lead has, so each variant gets a fair share.
  #  - Once a person has approved a default for the lead's segment, that variant is used most of the time,
  #    but explore_share of sends are still random so rotation never stops.
  # The assignment kind is recorded ("random" or "suggested"; a person's own pick is "manual"), because
  # only "random" sends are a fair basis for comparing variants.
  class VariantAssigner
    def initialize(approvals: Approvals.new, rng: Random.new, explore_share: Setting.get("results.explore_share"))
      @approvals = approvals
      @rng = rng
      @explore_share = explore_share
    end

    def call(labels:, segments:)
      return Assignment.new(nil, "manual") if labels.empty?

      preferred = @approvals.default_for(segments)
      return Assignment.new(preferred, "suggested") if preferred && labels.include?(preferred) && @rng.rand >= @explore_share

      Assignment.new(labels.sort.sample(random: @rng), "random")
    end
  end
end
