class TextMessageService
  class NotConfigured < StandardError; end

  def deliver(mobile, message)
    if Rails.env.production?
      raise NotConfigured, "No SMS provider is set up yet, so the text to #{mobile} was not sent"
    end

    Rails.logger.info("[text message] to +965#{mobile}: #{message}")
  end
end
