class ResultComponent < ViewComponent::Base
  def initialize(archive_file:, query: "")
    @query = query
    @archive_file = archive_file
  end

  def parents
    @parents ||=
      @archive_file.parents.map do |parent|
        text = highlight_query(CGI.escapeHTML(parent['name'].strip))
        if parent["id"].present?
          text = link_to text, archive_node_path(parent["id"]), class: "parents__item__link"
        end

        "<div class=\"parents__item\">#{text}</div>"
      end.join '<div class="parents__separator">/</div>'

    @parents.html_safe
  end

  def title
    highlight_query(@archive_file.title)
  end

  def date
    return @archive_file.source_date_text if @archive_file.source_date_text.present?

    @archive_file.source_date_years.join("-")
  end

  def date_corrected?
    @archive_file.source_date_start_uncorrected.present? ||
      @archive_file.source_date_end_uncorrected.present?
  end

  def date_correction_detail
    if @archive_file.source_date_start_uncorrected.present?
      "#{@archive_file.source_date_start_uncorrected.year} \u2192 #{@archive_file.source_date_start.year}"
    elsif @archive_file.source_date_end_uncorrected.present?
      "#{@archive_file.source_date_end_uncorrected.year} \u2192 #{@archive_file.source_date_end.year}"
    end
  end

  def summary
    highlight_query(@archive_file.summary)
  end

  def ris_link
    link_to @archive_file, format: :ris
  end

  private

  def highlight_query(text)
    return text if @query.blank? || text.blank?
    text.gsub(
      /(#{CGI.escapeHTML(@query)})/i,
      '<span class="result__highlight">\1</span>'
    ).html_safe
  end
end
