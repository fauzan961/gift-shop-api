require "test_helper"

class CurrentTest < ActiveSupport::TestCase
  teardown do
    Current.reset
  end

  test "has no session or user by default" do
    assert_nil Current.session
    assert_nil Current.user
  end

  test "gives the user of the current session" do
    Current.session = sessions(:layla_phone)

    assert_equal users(:layla), Current.user
  end

  test "forgets the session and user when reset" do
    Current.session = sessions(:layla_phone)
    Current.reset

    assert_nil Current.session
    assert_nil Current.user
  end
end
