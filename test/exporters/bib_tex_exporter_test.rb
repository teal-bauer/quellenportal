require 'test_helper'

class BibTexExporterTest < ActiveSupport::TestCase
  test 'it renders the correct bibtex' do
    archive_file = OpenStruct.new(
      id: 'ed3ff8a0-c65e-4efd-b5d3-96950687d291',
      title: 'Test Title',
      summary: 'Test Summary',
      language_code: 'ger',
      link: 'https://example.com/akte',
      parents: [{ 'name' => 'Bundesministerium für Familie und Jugend (BMFa)' }],
      source_date_start: '1961-01-01',
      source_date_end: '1963-12-31',
      source_date_text: '1961 - 1963'
    )
    bibtex = BibTexExporter.new(archive_file).export
    result = BibTeX.parse(bibtex).first

    assert_equal :unpublished, result.type
    assert_equal archive_file.title, result.title.to_s
    assert_equal archive_file.summary, result.abstract.to_s
    assert_equal archive_file.language_code, result.language.to_s
    assert_equal '1961', result.year
    assert_equal 'jan', result.month.to_s
    assert_equal 'issued:1961/1963', result.note.to_s
    # bibtex-ruby reformats authors as "last, first" — just check the parts are present
    assert_includes result.author.to_s, 'Bundesministerium'
    assert_includes result.author.to_s, 'BMFa'
  end

  test 'it handles missing end date' do
    archive_file = OpenStruct.new(
      title: 'Single Date',
      summary: '',
      language_code: 'ger',
      link: nil,
      parents: [],
      source_date_start: '1990-06-15',
      source_date_end: nil,
      source_date_text: '1990'
    )
    bibtex = BibTexExporter.new(archive_file).export
    result = BibTeX.parse(bibtex).first

    assert_equal '1990', result.year
    assert_equal 'issued:1990', result.note.to_s
  end
end
