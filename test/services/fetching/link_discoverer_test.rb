require "test_helper"

class Fetching::LinkDiscovererTest < ActiveSupport::TestCase
  test "finds about, careers and blog on the same host and ignores the rest" do
    html = <<~HTML
      <nav><a href="/about-us">About</a><a href="/careers">Careers</a><a href="https://other.com/blog">Blog</a></nav>
      <a href="/blog/">Our blog</a><a href="/pricing">Pricing</a><a href="mailto:a@b.com">Mail</a>
      <a href="/files/deck.pdf">About deck</a><a href="/about-us#team">Team</a>
    HTML
    found = Fetching::LinkDiscoverer.new.call(html, "https://acme.com/")

    assert_equal({ "about" => "https://acme.com/about-us", "careers" => "https://acme.com/careers",
                   "blog" => "https://acme.com/blog/" }, found)
  end

  test "prefers navigation links and resolves relative urls" do
    html = '<a href="team/jobs">Open jobs</a><nav><a href="/jobs">Jobs</a></nav>'
    assert_equal "https://acme.com/jobs", Fetching::LinkDiscoverer.new.call(html, "https://acme.com/")["careers"]
  end

  test "returns only the kinds it finds" do
    assert_equal({}, Fetching::LinkDiscoverer.new.call("<a href='/pricing'>x</a>", "https://acme.com/"))
  end
end
