module LeadsHelper
  # A "Source: ..." chip. Apollo fields show as "Apollo"; page URLs show as their path and link out.
  # Only http(s) URLs are linked, since sources come from model output.
  def source_chip(source)
    text = source.to_s.strip
    return tag.span("Source: Not found", class: "chip") if text.blank? || text.casecmp?("not found")
    return tag.span("Source: Apollo", class: "chip") if text.downcase.start_with?("apollo")

    url = Leads::LinkedinTarget.web_url(text)
    return tag.span("Source: #{text.truncate(40)}", class: "chip") unless url

    path = URI.parse(url).path.presence || "/"
    link_to("Source: #{path}", url, class: "chip", target: "_blank", rel: "noopener noreferrer")
  rescue URI::InvalidURIError
    tag.span("Source: #{text.truncate(40)}", class: "chip")
  end

  def website_label(company)
    company.domain.presence || company.website.to_s
  end

  def website_url(company)
    url = company.website.presence || company.domain.presence
    return nil unless url

    url.match?(%r{\Ahttps?://}i) ? url : "https://#{url}"
  end

  def ordered_messages(company)
    company.messages.sort_by { |message| Message::LABELS.index(message.label) }
  end

  # [label, id] pairs of recent account imports, for the import-batch filter.
  def import_batch_options
    ImportBatch.where(kind: "accounts").order(id: :desc).limit(20).map do |batch|
      [ "##{batch.id} #{batch.filename} (#{batch.created_at.strftime('%b %-d')})", batch.id ]
    end
  end

  def assignment_text(send_record)
    { "random" => "assigned at random", "manual" => "picked by you", "suggested" => "your approved default" }.fetch(send_record.assignment)
  end

  def variant_options(lead)
    ordered_messages(lead).map { |message| [ message.label_name, message.label ] }
  end

  def reply_options
    [ [ "Not recorded", "" ] ] + Company::REPLY_RESULTS.map { |value, label| [ label, value ] }
  end
end
