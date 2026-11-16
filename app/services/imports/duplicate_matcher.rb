module Imports
  # Finds an existing company that is almost certainly the same business as an incoming row:
  # the same cleaned-up name AND the same country AND the same city. All three must be known and equal.
  # Deliberately strict, because merging two different businesses is worse than keeping a duplicate.
  module DuplicateMatcher
    def self.call(attrs)
      key = NameKey.call(attrs[:name])
      country = normalize(attrs[:country])
      city = normalize(attrs[:city])
      return nil if key.blank? || country.blank? || city.blank?

      Company.where(name_key: key).find { |company| normalize(company.country) == country && normalize(company.city) == city }
    end

    def self.normalize(value) = value.to_s.downcase.squish
  end
end
