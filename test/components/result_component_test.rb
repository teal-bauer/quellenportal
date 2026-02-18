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
end
