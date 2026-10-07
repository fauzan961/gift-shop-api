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
        "featured" => true
      },
      occasion_json("valentines-day")
    )
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
