class ArchiveFilesController < ApplicationController
  def show
    @repository = MeilisearchRepository.new
    # Fetch from Meilisearch
    doc = @repository.get_file(params[:id])
    @archive_file = wrap_archive_file(doc)
    
    if @archive_file.nil?
      render plain: "Not found", status: 404
      return
    end
    
    respond_to do |format|
      format.ris { render ris: @archive_file }
      format.bib { render plain: BibTexExporter.new(@archive_file).export }
    end
  end
end
