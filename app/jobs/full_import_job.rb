class FullImportJob < ApplicationJob
  queue_as :imports
  limits_concurrency to: 1, key: "full_import"

  def perform(import_run_id)
    @run = ImportRun.find(import_run_id)
    return if @run.status == "cancelled"

    @live = MeilisearchRepository.new
    @shadow = MeilisearchRepository.new(suffix: "new")

    begin
      prepare_shadow_indices
      import_files
      wait_for_indexing
      swap_indices
      cleanup
      @run.complete!
    rescue => e
      @run.fail!("#{e.class}: #{e.message}")
      raise
    end
  end

  private

  def prepare_shadow_indices
    @run.update!(status: "preparing", started_at: @run.started_at || Time.current)

    # Only create shadow indices if this is a fresh run (no files completed yet)
    if @run.completed_files.zero?
      [@shadow.file_index, @shadow.node_index, @shadow.origin_index].each do |idx|
        resp = @live.delete_index(idx)
        @live.wait_for_task(resp["taskUid"], timeout: 600) if resp&.dig("taskUid")
      rescue
        nil
      end
      [@shadow.file_index, @shadow.node_index, @shadow.origin_index].each do |idx|
        resp = @live.post("/indexes", { uid: idx, primaryKey: "id" })
        @live.wait_for_task(resp["taskUid"], timeout: 600)
      end
      @shadow.configure_indices
    end
  end

  def import_files
    @run.update!(status: "importing")

    dir = Rails.root.join("data").to_s
    xml_files = Dir.glob("*.xml", base: dir).sort
    already_done = Set.new(@run.completed_filenames || [])

    @run.update!(total_files: xml_files.size)

    # Build shared caches for cross-file state
    origins_cache = @shadow.all_origins_for_cache.to_h { |o| [o["name"], o] }
    caches = {
      nodes: {},
      nodes_batch: [],
      files_batch: [],
      origins: origins_cache,
      origins_batch: [],
      progress_acc: 0.0
    }

    importer = BundesarchivImporter.new(dir, repository: @shadow)

    xml_files.each do |filename|
      # Check for cancellation before each file
      @run.reload
      return if @run.status == "cancelled"

      next if already_done.include?(filename)

      path = File.join(dir, filename)
      @run.update!(current_file: filename)

      records = importer.import_file(path, caches: caches)

      # Flush batches at file boundaries for clean checkpoints
      @shadow.upsert_files(caches[:files_batch]) if caches[:files_batch].any?
      @shadow.upsert_nodes(caches[:nodes_batch]) if caches[:nodes_batch].any?
      @shadow.upsert_origins(caches[:origins_batch]) if caches[:origins_batch].any?
      caches[:files_batch] = []
      caches[:nodes_batch] = []
      caches[:origins_batch] = []

      @run.mark_file_completed!(filename, records: records)

      Rails.logger.info "[FullImportJob] Completed #{filename}: #{records} records (#{@run.completed_files}/#{@run.total_files})"
    end
  end

  def wait_for_indexing
    @run.update!(status: "swapping", current_file: nil)

    loop do
      all_done = [@shadow.file_index, @shadow.node_index, @shadow.origin_index].all? do |idx|
        stats = @live.get("/indexes/#{idx}/stats")
        !stats["isIndexing"]
      end
      break if all_done
      sleep 5
    end
  end

  def swap_indices
    pairs = [
      { indexes: [@live.file_index, @shadow.file_index] },
      { indexes: [@live.node_index, @shadow.node_index] },
      { indexes: [@live.origin_index, @shadow.origin_index] }
    ]
    resp = @live.swap_indexes(pairs)
    @live.wait_for_task(resp["taskUid"], timeout: 300)
  end

  def cleanup
    [@shadow.file_index, @shadow.node_index, @shadow.origin_index].each do |idx|
      @live.delete_index(idx)
    end

    Rails.cache.delete("origins/with_file_counts")
    Rails.cache.delete("archive_files/decade_counts")
    Rails.cache.delete("browse/tab_counts")
  end
end
