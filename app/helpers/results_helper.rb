module ResultsHelper
  # "9 of 40" always; the percentage only when the sample is big enough, otherwise a grey "too few to judge".
  def rate_text(cell, report)
    count = tag.span(cell.to_s)
    return safe_join([ count, " ", tag.span("too few to judge", class: "muted") ]) unless report.reliable?(cell)

    safe_join([ count, " ", tag.strong(number_to_percentage(cell.rate * 100, precision: 0)) ])
  end

  def default_label(key)
    dimension, segment = key.split(":", 2)
    "#{dimension.capitalize}: #{segment}"
  end
end
