class ArchiveFilesController < ApplicationController
  def show
    @repository = MeilisearchRepository.new
    # Fetch from Meilisearch
    doc = @repository.get_file(params[:id])
    @archive_file = OpenStruct.new(doc) if doc
    
    respond_to do |format|
      format.ris { render ris: @archive_file }
      format.bib { render plain: BibTexExporter.new(@archive_file).export }
    end
  end
end
