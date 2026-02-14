require "test_helper"

class ArchiveFileTrigramTest < ActiveSupport::TestCase
  def setup
    BundesarchivImporter.new("test/fixtures/files/dataset-tiny").run
    ArchiveFile.reindex

    @example_archive_file = ArchiveFile.find_by(source_id: "DE-1958_8a0ff3f6-46b3-443a-9e48-946e790301e0")
  end

  test "search finds archive files by quoted title phrase" do
    # Users need to quote phrases for exact matching with the new FTS5 behavior
    assert_equal 1, ArchiveFileTrigram.search("\"#{@example_archive_file.title}\"").count
  end

  test "search finds archive files by quoted call number" do
    # Call numbers contain special characters, so need quoting
    assert_equal 1, ArchiveFileTrigram.search("\"#{@example_archive_file.call_number}\"").count
  end

  test "search supports boolean AND operator" do
    # Quote individual terms to avoid FTS5 interpreting them as column names
    title_words = @example_archive_file.title.split.reject { |w| w.length < 4 }.first(2)
    if title_words.length >= 2
      results = ArchiveFileTrigram.search("\"#{title_words[0]}\" AND \"#{title_words[1]}\"")
      assert results.count >= 1
    end
  end

  test "search supports prefix matching with wildcard" do
    # Take first 4 characters of title as prefix
    prefix = @example_archive_file.title[0, 4]
    results = ArchiveFileTrigram.search("#{prefix}*")
    assert results.count >= 1
  end

  test "in_node scope filters by archive node" do
    node = @example_archive_file.archive_node
    results = ArchiveFileTrigram.search("\"#{@example_archive_file.title}\"").in_node(node.id)
    assert_equal 1, results.count
  end

  test "in_node scope includes descendant nodes" do
    # Get the root node and search within it
    root_node = @example_archive_file.archive_node.parents.first
    results = ArchiveFileTrigram.search("\"#{@example_archive_file.title}\"").in_node(root_node.id)
    assert_equal 1, results.count
  end

  test "in_node scope returns none for non-existent node" do
    results = ArchiveFileTrigram.search("\"#{@example_archive_file.title}\"").in_node(999999)
    assert_equal 0, results.count
  end

  test "in_node scope returns all when node_id is blank" do
    quoted_title = "\"#{@example_archive_file.title}\""
    all_results = ArchiveFileTrigram.search(quoted_title)
    filtered_results = ArchiveFileTrigram.search(quoted_title).in_node(nil)
    assert_equal all_results.count, filtered_results.count
  end
end
