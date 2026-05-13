require 'test_helper'

class IconHelperTest < ActionView::TestCase
  include IconHelper

  test "renders a known icon as inline svg" do
    html = icon(:copy)
    assert_match %r{\A<svg }, html
    assert_match %r{viewBox="0 0 24 24"}, html
    assert_match %r{width="16"}, html
    assert_match %r{height="16"}, html
    assert_match %r{stroke="currentColor"}, html
    assert html.html_safe?
  end

  test "supports custom size" do
    html = icon(:search, size: 20)
    assert_match %r{width="20"}, html
    assert_match %r{height="20"}, html
  end

  test "passes through aria-label when provided" do
    html = icon(:download, label: "Herunterladen")
    assert_match %r{aria-label="Herunterladen"}, html
    assert_match %r{role="img"}, html
  end

  test "marks icon as decorative when no label given" do
    html = icon(:copy)
    assert_match %r{aria-hidden="true"}, html
  end

  test "raises on unknown icon" do
    assert_raises(KeyError) { icon(:nonexistent) }
  end

  test "accepts string names interchangeably with symbols" do
    assert_equal icon(:"arrow-right"), icon("arrow-right")
  end
end
