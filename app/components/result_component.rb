class ResultComponent < ViewComponent::Base
  def initialize(archive_file:, query: '')
    @query = query
    @archive_file = archive_file
  end

  def parents
    @parents ||=
      @archive_file.parents.map do |parent|
        text = highlight_query(CGI.escapeHTML(parent['name'].strip).html_safe)
        text = link_to text, archive_node_path(parent['id']), class: 'parents__item__link' if parent['id'].present?

        "<div class=\"parents__item\">#{text}</div>"
      end.join '<div class="parents__separator">/</div>'

    @parents.html_safe
  end

  def title
    highlight_query(@archive_file.title)
  end

  def date
    return @archive_file.source_date_text if @archive_file.source_date_text.present?

    years = []
    start_date = @archive_file.source_date_start ? Date.parse(@archive_file.source_date_start.to_s) : nil
    end_date = @archive_file.source_date_end ? Date.parse(@archive_file.source_date_end.to_s) : nil

    if start_date && end_date
      if start_date.year == end_date.year
        years << start_date.year.to_s
      else
        years << start_date.year.to_s
        years << end_date.year.to_s
      end
    elsif start_date
      years << start_date.year.to_s
    end
    
    years.join('-')
  end

  def date_corrected?
    @archive_file.source_date_start_uncorrected.present? ||
      @archive_file.source_date_end_uncorrected.present?
  end

  def date_correction_detail
    start_date = @archive_file.source_date_start ? Date.parse(@archive_file.source_date_start.to_s) : nil
    end_date = @archive_file.source_date_end ? Date.parse(@archive_file.source_date_end.to_s) : nil
    start_uncorrected = @archive_file.source_date_start_uncorrected ? Date.parse(@archive_file.source_date_start_uncorrected.to_s) : nil
    end_uncorrected = @archive_file.source_date_end_uncorrected ? Date.parse(@archive_file.source_date_end_uncorrected.to_s) : nil

    if start_uncorrected.present?
      "#{start_uncorrected.year} \u2192 #{start_date.year}"
    elsif end_uncorrected.present?
      "#{end_uncorrected.year} \u2192 #{end_date.year}"
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
