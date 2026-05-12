require 'test_helper'

class ResultComponentTest < ViewComponent::TestCase
  setup do
    @archive_file = Minitest::Mock.new
  end

  def test_title_highlight
    @archive_file.expect(:title, 'Rechenzentrum Duisburg')

    component =
      ResultComponent.new(
        query: 'rechenzentrum',
        archive_file: @archive_file
      )

    assert_equal %(<span class="result__highlight">Rechenzentrum</span> Duisburg),
                 component.title
    @archive_file.verify
  end

  def test_date
    @archive_file.expect(:source_date_text, '1989')
    @archive_file.expect(:source_date_text, '1989')

    component =
      ResultComponent.new(
        query: 'rechenzentrum',
        archive_file: @archive_file
      )

    assert_equal '1989', component.date
    @archive_file.verify
  end

  def test_summary_highlight
    @archive_file.expect(:summary, 'Das Rechenzentrum in Duisburg')

    component =
      ResultComponent.new(
        query: 'rechenzentrum',
        archive_file: @archive_file
      )

    assert_equal %(Das <span class="result__highlight">Rechenzentrum</span> in Duisburg),
                 component.summary
    @archive_file.verify
  end

  def test_summary_highlight_with_regex_metacharacters
    @archive_file.expect(:summary, 'Bericht über (1949) Akten')

    component =
      ResultComponent.new(
        query: '(1949)',
        archive_file: @archive_file
      )

    assert_equal %(Bericht über <span class="result__highlight">(1949)</span> Akten),
                 component.summary
    @archive_file.verify
  end

  def test_title_highlight_with_dot_in_query_matches_literally
    @archive_file.expect(:title, 'Akten 1.9 und 1x9')

    component =
      ResultComponent.new(
        query: '1.9',
        archive_file: @archive_file
      )

    assert_equal %(Akten <span class="result__highlight">1.9</span> und 1x9),
                 component.title
    @archive_file.verify
  end

  def test_renders_with_icons_instead_of_dingbats
    @archive_file.expect(:title, 'A')
    @archive_file.expect(:summary, 'B')
    @archive_file.expect(:source_date_text, '1989')
    @archive_file.expect(:source_date_text, '1989')
    @archive_file.expect(:source_date_start_uncorrected, nil)
    @archive_file.expect(:source_date_end_uncorrected, nil)
    @archive_file.expect(:parents, [])
    @archive_file.expect(:link, nil)
    @archive_file.expect(:link, nil)
    @archive_file.expect(:call_number, 'B 106/1')
    @archive_file.expect(:id, 'some-id')
    @archive_file.expect(:id, 'some-id')
    @archive_file.expect(:id, 'some-id')
    @archive_file.expect(:id, 'some-id')

    component = ResultComponent.new(query: 'a', archive_file: @archive_file)
    rendered = render_inline(component).to_html

    refute_match %r{⎘}, rendered
    refute_match %r{⤓}, rendered
    assert_match %r{<svg }, rendered
  end
end
