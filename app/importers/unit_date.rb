class UnitDate
  def initialize(node)
    @text = node&.text
    @normal = node&.attr("normal")

    @start_string, @end_string = @normal&.split("/")

    @start_date = parse_iso8601_string(@start_string)
    @end_date = parse_iso8601_string(@end_string)
  end

  attr_reader :start_date, :text

  def range?
    @end_date.present?
  end

  def end_date
    @end_date || @start_date
  end

  private

  def parse_iso8601_string(date_string)
    return nil unless date_string.present?

    begin
      date = Date.iso8601(date_string)
      return nil unless date.year.between?(1900, 2100)
      date
    rescue Date::Error
      nil
    end
  end
end
