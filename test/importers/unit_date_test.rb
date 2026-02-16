require "test_helper"

class UnitDateTest < ActiveSupport::TestCase
  private

  def make_node(normal:, text: "")
    xml = %(<unitdate normal="#{normal}">#{text}</unitdate>)
    Nokogiri.XML(xml).xpath("unitdate").first
  end

  public

  test "Parses a date range correctly" do
    xml_string = <<~HEREDOC
      <?xml version="1.0" encoding="UTF-8"?>
        <unitdate encodinganalog="3.1.3" era="ce" calendar="gregorian" normal="1959-01-01/1959-12-31">1959</unitdate>
      </xml>
    HEREDOC

    node = Nokogiri.XML(xml_string).xpath("unitdate").first

    date_parser = UnitDate.new(node)

    assert date_parser.range?
    assert_equal Date.new(1959, 1, 1), date_parser.start_date
    assert_equal Date.new(1959, 12, 31), date_parser.end_date
  end

  test "Parses a single date correctly" do
    xml_string = <<~HEREDOC
      <?xml version="1.0" encoding="UTF-8"?>
        <unitdate encodinganalog="3.1.3" era="ce" calendar="gregorian" normal="1920-01-01">1. 1. 1920</unitdate>
      </xml>
    HEREDOC

    node = Nokogiri.XML(xml_string).xpath("unitdate").first

    date_parser = UnitDate.new(node)

    refute date_parser.range?
    assert_equal Date.new(1920, 1, 1), date_parser.start_date
    assert_equal Date.new(1920, 1, 1), date_parser.end_date
  end

  test "Fails gracefully when the date is not parseable" do
    xml_string = <<~HEREDOC
      <?xml version="1.0" encoding="UTF-8"?>
        <unitdate encodinganalog="3.1.3" era="ce" calendar="gregorian" normal="">Kein Datum</unitdate>
      </xml>
    HEREDOC

    node = Nokogiri.XML(xml_string).xpath("unitdate").first

    date_parser = UnitDate.new(node)

    refute date_parser.range?
    assert_nil date_parser.start_date
    assert_nil date_parser.end_date
  end

  test "rejects sentinel year 2222 (Bundesarchiv placeholder for undated)" do
    node = make_node(normal: "2222-01-01/2222-12-31", text: "o. Dat.")
    date_parser = UnitDate.new(node)

    assert_nil date_parser.start_date
    assert_nil date_parser.end_date
  end

  test "rejects future years" do
    node = make_node(normal: "9360-01-01/9360-12-31")
    date_parser = UnitDate.new(node)

    assert_nil date_parser.start_date
  end

  test "allows legitimate medieval dates" do
    node = make_node(normal: "1190-01-01/1190-12-31", text: "1190")
    date_parser = UnitDate.new(node)

    assert_equal 1190, date_parser.start_date.year
  end

  test "fixes OCR typo 1040 to 1940 when end date is 1941" do
    node = make_node(normal: "1040-01-01/1941-12-31", text: "Sept. 1040-Dez. 1941")
    date_parser = UnitDate.new(node)

    assert_equal 1940, date_parser.start_date.year
    assert_equal 1941, date_parser.end_date.year
  end

  test "fixes century-off typo 1800 to 1900 when end date is 1960" do
    node = make_node(normal: "1800-01-01/1960-12-31")
    date_parser = UnitDate.new(node)

    assert_equal 1900, date_parser.start_date.year
  end

  test "does not fix legitimate wide range within 150 years" do
    node = make_node(normal: "1853-01-01/1964-12-31")
    date_parser = UnitDate.new(node)

    assert_equal 1853, date_parser.start_date.year
    assert_equal 1964, date_parser.end_date.year
  end

  test "does not fix legitimate pre-modern range" do
    node = make_node(normal: "1582-01-01/1683-12-31", text: "1582-1683")
    date_parser = UnitDate.new(node)

    assert_equal 1582, date_parser.start_date.year
    assert_equal 1683, date_parser.end_date.year
  end

  test "Fails gracefully when normalised date is not prsent" do
    xml_string = <<~HEREDOC
      <?xml version="1.0" encoding="UTF-8"?>
        <unitdate encodinganalog="3.1.3">Kein Datum</unitdate>
      </xml>
    HEREDOC

    node = Nokogiri.XML(xml_string).xpath("unitdate").first

    date_parser = UnitDate.new(node)

    refute date_parser.range?
    assert_nil date_parser.start_date
    assert_nil date_parser.end_date
  end
end
