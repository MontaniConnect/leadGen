module Drafting
  # Hard checks on a message body. Used on model output and, later, on text a person edits.
  class MessageValidator
    def self.word_count(body) = body.to_s.split.size

    def initialize(max_words: Setting.get("drafting.max_words"), banned_phrases: Setting.get("drafting.banned_phrases"))
      @max_words = max_words
      @banned_phrases = banned_phrases
    end

    # Returns problems as short strings; empty means the message is acceptable.
    def call(body)
      text = body.to_s.strip
      return [ "empty" ] if text.empty?

      problems = []
      count = self.class.word_count(text)
      problems << "over_word_limit (#{count} > #{@max_words})" if count > @max_words
      problems << "no_closing_question" unless text.end_with?("?")
      problems << "exclamation_mark" if text.include?("!")
      @banned_phrases.each { |phrase| problems << "banned_phrase: #{phrase}" if text.downcase.include?(phrase.downcase) }
      problems
    end
  end
end
