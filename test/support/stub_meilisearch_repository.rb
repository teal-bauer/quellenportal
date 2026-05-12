# In-memory stand-in for MeilisearchRepository, suitable for importer tests.
# Records all documents that get upserted so tests can assert on the result.
class StubMeilisearchRepository
  attr_reader :files, :nodes, :origins

  def initialize
    @files = []
    @nodes = []
    @origins = []
  end

  def configure_indices; end

  def all_origins_for_cache
    []
  end

  def upsert_files(documents)
    @files.concat(documents)
  end

  def upsert_nodes(documents)
    @nodes.concat(documents)
  end

  def upsert_origins(documents)
    @origins.concat(documents)
  end

  def find_file(id)
    @files.find { |f| f[:id] == id }
  end
end
