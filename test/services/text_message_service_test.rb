require "test_helper"

class TextMessageServiceTest < ActiveSupport::TestCase
  setup do
    @service = TextMessageService.new
  end

  test "deliver writes the text to the log outside production" do
    log = capture_log { @service.deliver("50000001", "Your code is 4821") }

    assert_includes log, "[text message] to +96550000001: Your code is 4821"
  end

  test "deliver adds the Kuwait country code to the mobile number" do
    log = capture_log { @service.deliver("60000002", "Hello") }

    assert_includes log, "+96560000002"
  end

  test "deliver refuses in production until a provider is connected" do
    with_rails_env("production") do
      error = assert_raises(TextMessageService::NotConfigured) { @service.deliver("50000001", "Your code is 4821") }
      assert_includes error.message, "50000001"
    end
  end

  test "deliver never writes the text to the log in production" do
    with_rails_env("production") do
      log = capture_log do
        assert_raises(TextMessageService::NotConfigured) { @service.deliver("50000001", "Your code is 4821") }
      end

      assert_not_includes log, "4821"
    end
  end

  private
    def capture_log
      original = Rails.logger
      output = StringIO.new
      Rails.logger = ActiveSupport::Logger.new(output)
      yield
      output.string
    ensure
      Rails.logger = original
    end

    def with_rails_env(name)
      original = Rails.env
      Rails.env = name
      yield
    ensure
      Rails.env = original
    end
end
