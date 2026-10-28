require "test_helper"

# Tests the error responses every controller shares, through a small
# controller that exists only for these tests.
class ApplicationControllerTest < ActionDispatch::IntegrationTest
  class ErrorsController < ApplicationController
    def missing
      Product.find_by!(slug: "does-not-exist")
    end

    def invalid
      User.create!(mobile: "40000000", email: "not-an-email", full_name: "a" * 101)
    end

    def valid
      render json: { data: "ok" }
    end
  end

  with_routing do |routes|
    routes.draw do
      get "test/missing", to: "application_controller_test/errors#missing"
      get "test/invalid", to: "application_controller_test/errors#invalid"
      get "test/valid", to: "application_controller_test/errors#valid"
    end
  end

  # ---------- Not found ----------

  test "a missing record returns not found in the shared format" do
    get "/test/missing"

    assert_response :not_found
    assert_equal "application/json", response.media_type
    assert_equal({ "error" => { "code" => "not_found", "message" => "Product not found" } }, response.parsed_body)
  end

  # ---------- Validation failed ----------

  test "an invalid record returns unprocessable content in the shared format" do
    get "/test/invalid"

    assert_response :unprocessable_content
    assert_equal "application/json", response.media_type
    assert_equal %w[ code message details ], response.parsed_body["error"].keys
    assert_equal "validation_failed", response.parsed_body.dig("error", "code")
  end

  test "an invalid record lists every failed field with its messages" do
    get "/test/invalid"

    details = response.parsed_body.dig("error", "details")
    assert_equal [ "is invalid" ], details["mobile"]
    assert_equal [ "is invalid" ], details["email"]
    assert_equal [ "is too long (maximum is 100 characters)" ], details["fullName"]
  end

  test "an invalid record uses camelCase field names in the details" do
    get "/test/invalid"

    details = response.parsed_body.dig("error", "details")
    assert_includes details.keys, "fullName"
    assert_not_includes details.keys, "full_name"
  end

  test "an invalid record includes a readable message" do
    get "/test/invalid"

    assert_match(/\AValidation failed: /, response.parsed_body.dig("error", "message"))
  end

  test "an invalid record is not saved" do
    assert_no_difference -> { User.count } do
      get "/test/invalid"
    end
  end

  # ---------- Normal responses ----------

  test "a normal response is not affected" do
    get "/test/valid"

    assert_response :success
    assert_equal({ "data" => "ok" }, response.parsed_body)
  end
end
