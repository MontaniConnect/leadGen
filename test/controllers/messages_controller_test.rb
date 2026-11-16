require "test_helper"

class MessagesControllerTest < ActionDispatch::IntegrationTest
  include LeadsTestHelper

  setup { @message = lead(name: "Acme").messages.find_by!(label: "curious_question") }

  test "saving an edit stores the text, marks it edited and recounts words" do
    patch message_path(@message), params: { message: { body: "Hi Ada, short note?" } }

    assert_response :no_content
    @message.reload
    assert_equal "Hi Ada, short note?", @message.body
    assert_equal "edited", @message.status
    assert_equal 4, @message.word_count
  end

  test "an unchanged save leaves the status alone and a sent message stays sent" do
    patch message_path(@message), params: { message: { body: @message.body } }
    assert_equal "draft", @message.reload.status

    @message.update!(status: "sent")
    patch message_path(@message), params: { message: { body: "Hi Ada, changed after sending?" } }
    assert_equal "sent", @message.reload.status
  end

  test "an over-length edit is saved (the screen warns, it does not block)" do
    patch message_path(@message), params: { message: { body: "word " * 70 } }
    assert_response :no_content
    assert_equal 70, @message.reload.word_count
  end

  test "a blank edit is refused and the old text is kept" do
    original = @message.body
    patch message_path(@message), params: { message: { body: "  " } }
    assert_response :unprocessable_entity
    assert_equal original, @message.reload.body
  end
end
