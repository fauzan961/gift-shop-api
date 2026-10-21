require "test_helper"

class OccasionsControllerTest < ActionDispatch::IntegrationTest
  test "index responds with JSON" do
    get occasions_url

    assert_response :success
    assert_equal "application/json", response.media_type
  end

  test "index wraps the list in a data key only" do
    get occasions_url

    assert_equal [ "data" ], response.parsed_body.keys
  end

  test "index lists active occasions in position order" do
    get occasions_url

    assert_equal %w[ valentines-day birthday graduation ], slugs
  end

  test "index leaves out inactive occasions" do
    get occasions_url

    assert_not_includes slugs, occasions(:hidden).slug
  end

  test "index returns every field in both languages" do
    get occasions_url

    assert_equal(
      {
        "slug" => "valentines-day",
        "nameEn" => "Valentine's Day",
        "nameAr" => "عيد الحب",
        "emoji" => "💕",
        "taglineEn" => "Say it with roses",
        "taglineAr" => "عبّر بالورود",
        "image" => "/assets/images/flowers.jpg",
        "occursOn" => (Date.current + 30).iso8601,
        "featured" => true,
        "productCount" => 1
      },
      occasion_json("valentines-day")
    )
  end

  test "index counts the active products for each occasion" do
    get occasions_url

    assert_equal 2, occasion_json("birthday")["productCount"]
  end

  test "index shows zero products for an occasion without active products" do
    get occasions_url

    assert_equal 0, occasion_json("graduation")["productCount"]
  end

  test "index leaves inactive products out of the count" do
    ProductOccasion.create!(product: products(:hidden_product), occasion: occasions(:valentines_day))

    get occasions_url

    assert_equal 1, occasion_json("valentines-day")["productCount"]
  end

  test "index sends the product count as a number" do
    get occasions_url

    assert_kind_of Integer, occasion_json("birthday")["productCount"]
  end

  test "index takes the same number of queries however many occasions exist" do
    5.times { |n| Occasion.create!(name_en: "Extra #{n}", slug: "extra-#{n}", position: 10 + n) }

    assert_queries_count(2) { get occasions_url }
  end

  test "index returns null for an occasion without a date" do
    get occasions_url

    assert_nil occasion_json("birthday")["occursOn"]
  end

  test "index returns null for a date that has passed" do
    get occasions_url

    assert_nil occasion_json("graduation")["occursOn"]
  end

  test "index returns the featured flag for every occasion" do
    get occasions_url

    assert_equal true, occasion_json("valentines-day")["featured"]
    assert_equal false, occasion_json("birthday")["featured"]
  end

  test "index returns null for missing Arabic text" do
    get occasions_url

    assert_nil occasion_json("birthday")["nameAr"]
    assert_nil occasion_json("birthday")["taglineAr"]
  end

  test "index returns an empty list when there are no occasions" do
    ProductOccasion.delete_all
    Occasion.delete_all

    get occasions_url

    assert_response :success
    assert_equal [], response.parsed_body["data"]
  end

  private
    def slugs
      response.parsed_body["data"].map { |occasion| occasion["slug"] }
    end

    def occasion_json(slug)
      response.parsed_body["data"].find { |occasion| occasion["slug"] == slug }
    end
end
