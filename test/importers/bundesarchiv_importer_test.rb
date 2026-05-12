require 'test_helper'

class BundesarchivImporterTest < ActiveSupport::TestCase
  def import_dataset(dir)
    repo = StubMeilisearchRepository.new
    BundesarchivImporter.new(dir, repository: repo).run
    repo
  end

  test 'importer creates the right amount of archive files from fixtures' do
    repo = import_dataset('test/fixtures/files/dataset-tiny')
    assert_equal 794, repo.files.size
  end

  # ed3ff8a0-c65e-4efd-b5d3-96950687d291 lives in DE-1958_B_153.xml
  test 'importer extracts the correct date and origins for a known record' do
    repo = import_dataset('test/fixtures/files/dataset-tiny')

    file = repo.find_file('ed3ff8a0-c65e-4efd-b5d3-96950687d291')
    assert_not_nil file, 'expected to find the seeded archive file in the stub'

    assert_equal '1961-01-01', file[:source_date_start]
    assert_equal '1963-12-31', file[:source_date_end]
    assert_equal '', file[:source_date_text]

    assert_equal ['Bundesministerium für Familie und Jugend (BMFa)', 'J 4 (1961)'],
                 file[:origin_names]

    origin_docs = file[:origin_names].map { |name| repo.origins.find { |o| o[:name] == name } }
    assert_equal 'final', origin_docs[0][:label]
    assert_equal 'organisational unit', origin_docs[1][:label]
  end
end
