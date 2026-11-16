module Outreach
  # Which variant a send was given, and how: "random" (a fair draw), "suggested" (an approved default)
  # or "manual" (a person's own pick).
  Assignment = Data.define(:variant, :assignment)
end
