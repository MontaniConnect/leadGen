require "test_helper"

class Fetching::TextExtractorTest < ActiveSupport::TestCase
  test "strips scripts, navigation, footer and collapses whitespace" do
    html = <<~HTML
      <html><head><style>.x{}</style><script>var a=1</script></head>
      <body><header>Menu Home</header><nav>Products</nav>
      <main><h1>We build   software</h1><p>For logistics teams.</p></main>
      <footer>Copyright</footer></body></html>
    HTML
    assert_equal "We build software For logistics teams.", Fetching::TextExtractor.new(max_words: 100).call(html)
  end

  test "truncates to max_words" do
    html = "<body><p>#{(1..50).to_a.join(' ')}</p></body>"
    assert_equal 10, Fetching::TextExtractor.new(max_words: 10).call(html).split.size
  end

  test "empty document gives empty text" do
    assert_equal "", Fetching::TextExtractor.new(max_words: 10).call("")
  end
end
