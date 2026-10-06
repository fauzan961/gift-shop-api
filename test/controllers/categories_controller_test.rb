require "test_helper"

class CategoriesControllerTest < ActionDispatch::IntegrationTest
  test "index responds with JSON" do
    get categories_url

    assert_response :success
    assert_equal "application/json", response.media_type
  end

  test "index lists active categories in position order" do
    get categories_url

    slugs = response.parsed_body["data"].map { |category| category["slug"] }
    assert_equal [ "flowers", "cakes" ], slugs
  end

  test "index leaves out inactive categories" do
    get categories_url

    slugs = response.parsed_body["data"].map { |category| category["slug"] }
    assert_not_includes slugs, categories(:hidden).slug
  end

  test "index returns every field in both languages" do
    get categories_url

    flowers = response.parsed_body["data"].first
    assert_equal(
      {
        "slug" => "flowers",
        "nameEn" => "Flowers",
        "nameAr" => "زهور",
        "emoji" => "💐",
        "taglineEn" => "Hand-tied blooms, cut fresh daily",
        "taglineAr" => "باقات مصنوعة يدويًا، تُقطف طازجة يوميًا",
        "image" => "/assets/images/flowers.jpg",
        "theme" => "tint-blush"
      },
      flowers
    )
  end

  test "index returns null for missing Arabic text" do
    get categories_url

    cakes = response.parsed_body["data"].find { |category| category["slug"] == "cakes" }
    assert_nil cakes["nameAr"]
    assert_nil cakes["taglineAr"]
  end

  test "index returns an empty list when there are no categories" do
    Category.delete_all

    get categories_url

    assert_response :success
    assert_equal [], response.parsed_body["data"]
  end
end
