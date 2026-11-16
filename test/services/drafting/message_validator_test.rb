require "test_helper"

class Drafting::MessageValidatorTest < ActiveSupport::TestCase
  def check(body) = Drafting::MessageValidator.new.call(body)
  def words(count) = (Array.new(count - 1, "word") + [ "word?" ]).join(" ")

  test "a good message has no problems" do
    assert_empty check("Hi Ada, how do you split work between teams? We help however it fits. Anything stretched?")
  end

  test "50 words is the limit: 50 passes, 51 is rejected" do
    assert_empty check(words(50))
    assert_equal [ "over_word_limit (51 > 50)" ], check(words(51))
  end

  test "must end with a question" do
    assert_equal [ "no_closing_question" ], check("Hi Ada, happy to help.")
  end

  test "exclamation marks, flattery and boilerplate are rejected" do
    problems = check("Hi Ada! I hope this finds you well, your work is impressive. Interested?")
    assert_includes problems, "exclamation_mark"
    assert_includes problems, "banned_phrase: hope this finds you well"
    assert_includes problems, "banned_phrase: impressive"
  end

  test "empty text is rejected" do
    assert_equal [ "empty" ], check("  ")
  end

  test "the limit comes from settings" do
    Setting.set("drafting.max_words", 10)
    assert_equal [ "over_word_limit (11 > 10)" ], check(words(11))
  end

  test "the Message model stores the word count" do
    company = Company.create!(name: "A")
    message = company.messages.create!(label: "curious_question", body: "Hi Ada, quick one?")
    assert_equal 4, message.word_count
  end
end
