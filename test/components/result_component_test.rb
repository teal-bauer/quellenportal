require 'test_helper'

class ResultComponentTest < ViewComponent::TestCase
  setup do
    @archive_file = Minitest::Mock.new
  end

  def test_title_renders_meilisearch_highlight_tokens_as_spans
    @archive_file.expect(:title, "[[HL]]Rechenzentrum[[/HL]] Duisburg")

    component = ResultComponent.new(query: "rechenzentrum", archive_file: @archive_file)

    assert_equal %(<span class="result__highlight">Rechenzentrum</span> Duisburg),
                 component.title
    @archive_file.verify
  end

  def test_title_without_tokens_passes_through_with_html_escaping
    @archive_file.expect(:title, "Bericht & <Anhang>")

    component = ResultComponent.new(query: "", archive_file: @archive_file)

    assert_equal "Bericht &amp; &lt;Anhang&gt;", component.title
    @archive_file.verify
  end

  def test_title_handles_typo_tolerant_partial_match
    # Simulates what Meilisearch returns for q=jesus against "Prof. Arnd Jessen"
    @archive_file.expect(:title, "Prof. Arnd [[HL]]Jesse[[/HL]]n")

    component = ResultComponent.new(query: "jesus", archive_file: @archive_file)

    assert_equal %(Prof. Arnd <span class="result__highlight">Jesse</span>n),
                 component.title
    @archive_file.verify
  end

  def test_summary_renders_meilisearch_highlight_tokens
    @archive_file.expect(:summary, "Das [[HL]]Rechenzentrum[[/HL]] in Duisburg")

    component = ResultComponent.new(query: "rechenzentrum", archive_file: @archive_file)

    assert_equal %(Das <span class="result__highlight">Rechenzentrum</span> in Duisburg),
                 component.summary
    @archive_file.verify
  end

  def test_date_returns_source_date_text
    @archive_file.expect(:source_date_text, "1989")
    @archive_file.expect(:source_date_text, "1989")

    component = ResultComponent.new(query: "anything", archive_file: @archive_file)

    assert_equal "1989", component.date
    @archive_file.verify
  end

  def test_renders_with_icons_instead_of_dingbats
    @archive_file.expect(:title, "A")
    @archive_file.expect(:summary, "B")
    @archive_file.expect(:source_date_text, "1989")
    @archive_file.expect(:source_date_text, "1989")
    @archive_file.expect(:source_date_start_uncorrected, nil)
    @archive_file.expect(:source_date_end_uncorrected, nil)
    @archive_file.expect(:parents, [])
    @archive_file.expect(:link, nil)
    @archive_file.expect(:link, nil)
    @archive_file.expect(:call_number, "B 106/1")
    @archive_file.expect(:id, "some-id")
    @archive_file.expect(:id, "some-id")
    @archive_file.expect(:id, "some-id")
    @archive_file.expect(:id, "some-id")

    component = ResultComponent.new(query: "a", archive_file: @archive_file)
    rendered = render_inline(component).to_html

    refute_match %r{⎘}, rendered
    refute_match %r{⤓}, rendered
    assert_match %r{<svg }, rendered
  end
end
