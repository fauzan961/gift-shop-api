require "test_helper"

class AddressesControllerTest < ActionDispatch::IntegrationTest
  NEW_ADDRESS = { address_type: "Other", address: "Street 7, House 22", block_area: "Block 2, Rumaithiya", city: "Hawalli" }

  # ---------- Listing ----------

  test "index lists the user's addresses with the default first" do
    newer_default = AddressService.new.create(users(:layla), NEW_ADDRESS.merge(is_default: true))

    get addresses_url, headers: bearer("layla-phone-token")

    assert_response :success
    assert_equal [ newer_default.id, *[ addresses(:layla_home).id, addresses(:layla_work).id ].sort ],
                 response.parsed_body["data"].pluck("id")
  end

  test "index returns each address in the API format" do
    get addresses_url, headers: bearer("layla-phone-token")

    assert_equal(
      {
        "id" => addresses(:layla_home).id,
        "addressType" => "Home",
        "address" => "Street 12, House 4",
        "blockArea" => "Block 5, Salmiya",
        "city" => "Kuwait City",
        "isDefault" => true
      },
      response.parsed_body["data"].first
    )
  end

  test "index never shows another user's addresses" do
    get addresses_url, headers: bearer("layla-phone-token")

    assert_not_includes response.parsed_body["data"].pluck("id"), addresses(:omar_home).id
  end

  test "index returns an empty list for a user without addresses" do
    get addresses_url, headers: bearer(SessionService.new.start(User.create!(mobile: "69999999")))

    assert_response :success
    assert_equal({ "data" => [] }, response.parsed_body)
  end

  # ---------- Adding ----------

  test "create saves the address and returns it" do
    assert_difference -> { users(:layla).addresses.count }, 1 do
      post addresses_url, headers: bearer("layla-phone-token"), as: :json, params: NEW_ADDRESS
    end

    assert_response :created
    address = users(:layla).addresses.order(:id).last
    assert_equal(
      {
        "id" => address.id,
        "addressType" => "Other",
        "address" => "Street 7, House 22",
        "blockArea" => "Block 2, Rumaithiya",
        "city" => "Hawalli",
        "isDefault" => false
      },
      response.parsed_body["data"]
    )
  end

  test "create makes the first address the default" do
    token = SessionService.new.start(User.create!(mobile: "69999999"))

    post addresses_url, headers: bearer(token), as: :json, params: NEW_ADDRESS.merge(is_default: false)

    assert_equal true, response.parsed_body.dig("data", "isDefault")
  end

  test "create ignores user_id and unknown fields" do
    post addresses_url, headers: bearer("layla-phone-token"), as: :json,
         params: NEW_ADDRESS.merge(user_id: users(:omar).id, id: 1, colour: "red")

    assert_response :created
    assert_equal users(:layla), Address.find(response.parsed_body.dig("data", "id")).user
  end

  test "create rejects missing fields with details for each one" do
    assert_no_difference -> { Address.count } do
      post addresses_url, headers: bearer("layla-phone-token"), as: :json, params: {}
    end

    assert_response :unprocessable_content
    assert_equal "validation_failed", response.parsed_body.dig("error", "code")
    assert_equal %w[ addressType address blockArea city ].sort, response.parsed_body.dig("error", "details").keys.sort
  end

  test "create refuses an address past the limit" do
    (AddressService::MAX_PER_USER - 2).times { AddressService.new.create(users(:layla), NEW_ADDRESS) }

    assert_no_difference -> { Address.count } do
      post addresses_url, headers: bearer("layla-phone-token"), as: :json, params: NEW_ADDRESS
    end

    assert_response :unprocessable_content
    assert_equal(
      { "error" => { "code" => "address_limit_reached", "message" => "You can save up to 10 addresses." } },
      response.parsed_body
    )
  end

  # ---------- Editing ----------

  test "update changes the address and returns it" do
    patch address_url(addresses(:layla_work)), headers: bearer("layla-phone-token"), as: :json,
          params: { city: "Farwaniya" }

    assert_response :success
    assert_equal "Farwaniya", response.parsed_body.dig("data", "city")
    assert_equal "Farwaniya", addresses(:layla_work).reload.city
  end

  test "update can make another address the default" do
    patch address_url(addresses(:layla_work)), headers: bearer("layla-phone-token"), as: :json,
          params: { is_default: true }

    assert_equal true, response.parsed_body.dig("data", "isDefault")
    assert_not addresses(:layla_home).reload.is_default
  end

  test "update rejects an invalid change" do
    patch address_url(addresses(:layla_work)), headers: bearer("layla-phone-token"), as: :json,
          params: { city: "ab" }

    assert_response :unprocessable_content
    assert_equal [ "city" ], response.parsed_body.dig("error", "details").keys
    assert_equal "Kuwait City", addresses(:layla_work).reload.city
  end

  test "update cannot move an address to another user" do
    patch address_url(addresses(:layla_work)), headers: bearer("layla-phone-token"), as: :json,
          params: { user_id: users(:omar).id, city: "Farwaniya" }

    assert_response :success
    assert_equal users(:layla), addresses(:layla_work).reload.user
  end

  test "update of another user's address is not found and changes nothing" do
    patch address_url(addresses(:omar_home)), headers: bearer("layla-phone-token"), as: :json,
          params: { city: "Farwaniya" }

    assert_not_found
    assert_equal "Hawalli", addresses(:omar_home).reload.city
  end

  # ---------- Removing ----------

  test "destroy removes the address" do
    delete address_url(addresses(:layla_work)), headers: bearer("layla-phone-token")

    assert_response :no_content
    assert_empty response.body
    assert_not Address.exists?(addresses(:layla_work).id)
  end

  test "destroy of the default makes another address the default" do
    delete address_url(addresses(:layla_home)), headers: bearer("layla-phone-token")

    get addresses_url, headers: bearer("layla-phone-token")
    assert_equal [ [ addresses(:layla_work).id, true ] ], response.parsed_body["data"].pluck("id", "isDefault")
  end

  test "destroy of another user's address is not found and deletes nothing" do
    delete address_url(addresses(:omar_home)), headers: bearer("layla-phone-token")

    assert_not_found
    assert Address.exists?(addresses(:omar_home).id)
  end

  test "destroy of an address that does not exist is not found" do
    delete address_url(0), headers: bearer("layla-phone-token")

    assert_not_found
  end

  # ---------- Signing in ----------

  test "every action without a valid token is refused and changes nothing" do
    requests = [
      ->(headers) { get addresses_url, headers: headers },
      ->(headers) { post addresses_url, headers: headers, as: :json, params: NEW_ADDRESS },
      ->(headers) { patch address_url(addresses(:layla_work)), headers: headers, as: :json, params: { city: "Farwaniya" } },
      ->(headers) { delete address_url(addresses(:layla_work)), headers: headers }
    ]

    requests.each do |request|
      [ {}, bearer("not-a-real-token"), bearer("omar-expired-token") ].each do |headers|
        request.call(headers)

        assert_response :unauthorized
        assert_equal "unauthenticated", response.parsed_body.dig("error", "code")
      end
    end

    assert_equal 3, Address.count
    assert_equal "Kuwait City", addresses(:layla_work).reload.city
  end

  private
    def bearer(token)
      { "Authorization" => "Bearer #{token}" }
    end

    def assert_not_found
      assert_response :not_found
      assert_equal({ "error" => { "code" => "not_found", "message" => "Address not found" } }, response.parsed_body)
    end
end
