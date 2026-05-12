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
end
