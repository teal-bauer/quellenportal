class ApplicationController < ActionController::Base
  private

  def wrap_archive_file(doc)
    return nil if doc.nil?
    
    OpenStruct.new(doc).tap do |file|
      # Add source_dates helper
      file.source_dates = begin
        start_date = file.source_date_start
        end_date = file.source_date_end
        if end_date.blank? || start_date == end_date
          [start_date.to_s]
        else
          [start_date.to_s, end_date.to_s]
        end
      end

      # Add source_date_years helper
      file.source_date_years = begin
        start_date = file.source_date_start ? Date.parse(file.source_date_start.to_s) : nil
        end_date = file.source_date_end ? Date.parse(file.source_date_end.to_s) : nil
        
        if start_date.blank? && end_date.blank?
          []
        elsif end_date.blank? || start_date.year == end_date.year
          [start_date.year.to_s]
        else
          [start_date.year.to_s, end_date.year.to_s]
        end
      end
    end
  end
end
