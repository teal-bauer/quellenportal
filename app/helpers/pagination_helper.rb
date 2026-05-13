module PaginationHelper
  # German singular/plural is irregular enough (Aktenstück -> Aktenstücke,
  # Provenienz -> Provenienzen) that Kaminari's English-centric default
  # pluralization gives wrong output. Render the counter ourselves.
  def entries_info(paginatable, singular:, plural:)
    total = paginatable.total_count

    text =
      if total.zero?
        "Kein #{singular} gefunden"
      elsif total == 1
        "Zeige <b>1</b> #{singular}"
      elsif paginatable.total_pages == 1
        "Zeige <b>alle #{number_with_delimiter(total)}</b> #{plural}"
      else
        first = paginatable.offset_value + 1
        last = [paginatable.offset_value + paginatable.limit_value, total].min
        "Zeige #{plural} <b>#{first}&nbsp;-&nbsp;#{last}</b> von insgesamt <b>#{number_with_delimiter(total)}</b>"
      end

    text.html_safe
  end
end
