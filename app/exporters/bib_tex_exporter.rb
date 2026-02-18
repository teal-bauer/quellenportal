class BibTexExporter
  def initialize(archive_file)
    @archive_file = archive_file
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
                               year: @archive_file.source_date_start&.year,
                               month: @archive_file.source_date_start&.month,
                               note: issued_note
                             })
    bib.to_s
  end

  def issued_note
    years = @archive_file.source_date_years.join('/')
    "issued:#{years}"
  end
end
