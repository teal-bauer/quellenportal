class UnitDate
  SENTINEL_YEAR = 2222 # Bundesarchiv uses 2222 as placeholder for undated records
  MAX_PLAUSIBLE_YEAR = Date.today.year + 1

  def initialize(node)
    @text = node&.text
    @normal = node&.attr("normal")

    @start_string, @end_string = @normal&.split("/")

    @start_date = parse_iso8601_string(@start_string)
    @end_date = parse_iso8601_string(@end_string)

    try_fix_digit_typo if @start_date && @end_date
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
      return nil if date.year == SENTINEL_YEAR
      return nil if date.year > MAX_PLAUSIBLE_YEAR
      date
    rescue Date::Error
      nil
    end
  end

  # When a date range has an implausibly wide span (>150 years), try changing
  # a single digit in the outlier year to bring it close to the other year.
  # Covers OCR/transcription errors like 1040→1940, 1863→1963, 9360→1360.
  def try_fix_digit_typo
    span = @end_date.year - @start_date.year
    return if span.between?(0, 150)

    if span > 150
      # Start year is suspiciously old relative to end year
      fixed = fix_single_digit(@start_date, @end_date)
      @start_date = fixed if fixed
    elsif span < 0
      # Inverted range — try fixing whichever end is the outlier
      fixed = fix_single_digit(@end_date, @start_date)
      @end_date = fixed if fixed
    end
  end

  # Try changing one digit in `bad_date`'s year to produce a year that is
  # plausible relative to `good_date` (within 100 years, and maintaining
  # start <= end ordering).
  def fix_single_digit(bad_date, good_date)
    bad_year = bad_date.year.to_s.rjust(4, "0")
    good_year = good_date.year

    best = nil
    best_distance = Float::INFINITY

    4.times do |i|
      ("0".."9").each do |d|
        next if d == bad_year[i]

        candidate_year = (bad_year[0...i] + d + bad_year[i + 1..]).to_i
        next if candidate_year > MAX_PLAUSIBLE_YEAR
        next if candidate_year < 800 # nothing before 800 in Bundesarchiv

        distance = (candidate_year - good_year).abs
        next if distance > 100

        if distance < best_distance
          best_distance = distance
          best = Date.new(candidate_year, bad_date.month, bad_date.day)
        end
      end
    end

    best
  end
end
