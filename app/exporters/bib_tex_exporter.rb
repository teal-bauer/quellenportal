class BibTexExporter
  def initialize(archive_file)
    @archive_file = archive_file
    @start_date = @archive_file.source_date_start ? Date.parse(@archive_file.source_date_start.to_s) : nil
    @end_date = @archive_file.source_date_end ? Date.parse(@archive_file.source_date_end.to_s) : nil
  end

  def export
    author = (@archive_file.parents&.first || {})['name']
    bib = BibTeX::Bibliography.new
    bib << BibTeX::Entry.new({
                               bibtex_type: :unpublished,
                               url: @archive_file.link,
                               title: @archive_file.title,
                               abstract: @archive_file.summary,
                               language: @archive_file.language_code,
                               author: author,
                               year: @start_date&.year,
                               month: @start_date&.month,
                               note: issued_note
                             })
    bib.to_s
  end

  def issued_note
    years = []
    if @start_date && @end_date
      if @start_date.year == @end_date.year
        years << @start_date.year.to_s
      else
        years << @start_date.year.to_s
        years << @end_date.year.to_s
      end
    elsif @start_date
      years << @start_date.year.to_s
    end
    "issued:#{years.join('/')}"
  end
end
