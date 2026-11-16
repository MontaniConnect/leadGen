module Imports
  # A company name reduced to what identifies it: "Acme, Inc." and "ACME Incorporated" both become "acme".
  # Used only to find possible duplicates (together with country and city); it is never shown.
  module NameKey
    SUFFIXES = %w[inc incorporated llc ltd limited corp corporation co company plc pty gmbh llp lp sa ag bv nv].freeze

    def self.call(name)
      words = I18n.transliterate(name.to_s).downcase.gsub("&", " and ").gsub(/[^a-z0-9 ]/, " ").split
      words.shift if words.first == "the" && words.size > 1
      words.pop while words.size > 1 && SUFFIXES.include?(words.last)
      words.join
    end
  end
end
