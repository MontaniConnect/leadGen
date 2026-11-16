module Outreach
  # A sent message with the recipient's first name and company name replaced by placeholders, so it can be
  # shown to the drafting model as a style example without its specifics leaking into other leads.
  module Anonymizer
    GREETING = /\A(Hi|Hello|Hey)\s+[^,\n]{1,40},/

    def self.call(send_record)
      text = send_record.sent_body.to_s.squish
      first_name = send_record.contact&.first_name
      text = text.gsub(/\b#{Regexp.escape(first_name)}\b/, "<first name>") if first_name.present?
      name = send_record.company&.name
      text = text.gsub(/#{Regexp.escape(name)}/i, "<company>") if name.present?
      text.sub(GREETING) { "#{Regexp.last_match(1)} <first name>," }
    end
  end
end
