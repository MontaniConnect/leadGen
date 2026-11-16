require "test_helper"

class Fetching::SiteContactExtractorTest < ActiveSupport::TestCase
  def extract(html) = Fetching::SiteContactExtractor.new.call(html)

  test "name and title in one block" do
    assert_equal({ first_name: "Jane", last_name: "Doe", title: "Founder & CEO" },
                 extract("<p>Jane Doe, Founder &amp; CEO</p>"))
  end

  test "name block followed by title block" do
    html = "<div><h3>Maria Santos</h3><p>Chief Technology Officer</p></div>"
    assert_equal "Santos", extract(html)[:last_name]
  end

  test "title block followed by name block" do
    assert_equal "Lee", extract("<p>CEO</p><p>Sam Lee</p>")[:last_name]
  end

  test "picks the highest-ranked leader" do
    html = "<p>Ann Cole - CTO</p><p>Bob Ray - CEO</p>"
    assert_equal "Bob", extract(html)[:first_name]
  end

  test "ignores titles outside the leadership tiers and title-like names" do
    assert_nil extract("<p>Sales Rep Tom Hill</p><p>Tom Hill, Sales Representative</p>")
    assert_nil extract("<h2>Our Founder</h2><p>CEO</p>")
    assert_nil extract("<p>Assistant to the CEO</p><p>Pat Green</p>")
  end

  test "ignores navigation and footer text" do
    assert_nil extract("<nav>Jane Doe, CEO</nav><footer>Jane Doe, CEO</footer><p>We build things</p>")
  end

  test "returns nil when nothing is clear" do
    assert_nil extract("<p>We are a friendly team that loves software.</p>")
  end
end
