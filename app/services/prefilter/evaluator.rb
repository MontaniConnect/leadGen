module Prefilter
  # Decides pass/fail for one company. No network, no model. Pure function of company + rules.
  class Evaluator
    def initialize(rules, today: Date.current)
      @rules = rules
      @today = today
    end

    def call(company)
      reasons = fail_reasons(company)
      boosts = reasons.empty? ? boosts_for(company) : []
      Result.new(status: reasons.empty? ? "pass" : "fail", reasons: reasons, boosts: boosts)
    end

    private

    def fail_reasons(company)
      employee_reasons(company) + country_reasons(company) + naics_reasons(company) + keyword_reasons(company)
    end

    def employee_reasons(company)
      count = company.employees
      return [ "employees_unknown" ] if count.nil?
      return [ "employees_below_min" ] if count < @rules.min_employees
      return [ "employees_above_max" ] if count > @rules.max_employees

      []
    end

    def country_reasons(company)
      return [ "country_unknown" ] if company.country.blank?
      return [] if @rules.countries.map(&:downcase).include?(company.country.strip.downcase)

      [ "country_not_allowed" ]
    end

    def naics_reasons(company)
      codes = company.naics_codes.to_s.scan(/\d+/)
      @rules.excluded_naics_prefixes.select { |prefix| codes.any? { |code| code.start_with?(prefix) } }
                                    .map { |prefix| "excluded_naics: #{prefix}" }
    end

    def keyword_reasons(company)
      text = @rules.excluded_keyword_fields.map { |field| company.public_send(field) }.join(" ")
      @rules.excluded_keywords.select { |word| word_in?(text, word) }.map { |word| "excluded_keyword: #{word}" }
    end

    def boosts_for(company)
      technology_boosts(company) + keyword_boosts(company) + intent_boosts(company) + funding_boosts(company)
    end

    def technology_boosts(company)
      @rules.boost_technologies.select { |tech| word_in?(company.technologies, tech) }
                               .map { |tech| "technology: #{tech}" }
    end

    def keyword_boosts(company)
      text = [ company.keywords, company.industry ].join(" ")
      @rules.boost_keywords.select { |word| word_in?(text, word) }.map { |word| "keyword: #{word}" }
    end

    def intent_boosts(company)
      score = company.intent_score
      score && score >= @rules.intent_min_score ? [ "intent_score" ] : []
    end

    # Funding raised recently is the "Why Now" signal.
    def funding_boosts(company)
      raised = company.last_raised_at
      recent = raised && raised <= @today && raised >= @today - @rules.why_now_funding_days
      recent ? [ "funding_within_#{@rules.why_now_funding_days}_days" ] : []
    end

    def word_in?(text, word)
      text.to_s.match?(/(?<![[:alnum:]])#{Regexp.escape(word)}(?![[:alnum:]])/i)
    end
  end
end
