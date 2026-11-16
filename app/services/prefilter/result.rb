module Prefilter
  Result = Data.define(:status, :reasons, :boosts) do
    def pass? = status == "pass"
    def score = boosts.size
  end
end
