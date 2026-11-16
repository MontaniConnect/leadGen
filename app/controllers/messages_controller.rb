class MessagesController < ApplicationController
  # Saves an in-place edit of a drafted message. An over-length edit is saved (the screen warns instead).
  def update
    message = Message.find(params[:id])
    body = params.dig(:message, :body).to_s.strip
    return head :unprocessable_entity if body.blank?

    changed = body != message.body
    message.status = "edited" if changed && message.status == "draft"
    message.update!(body: body)
    head :no_content
  end
end
