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
        "theme" => "tint-blush",
        "productCount" => 1,
        "fromPrice" => 48.0
      },
      flowers
    )
  end

  test "index counts products linked as an extra category" do
    get categories_url

    # Cakes holds the teddy bear and chocolate box as their main category,
    # and the gift set as an extra one.
    cakes = category_json("cakes")
    assert_equal 3, cakes["productCount"]
    assert_equal 9.0, cakes["fromPrice"]
  end

  test "index leaves inactive products out of the count and lowest price" do
    products(:hidden_product).update_column(:price, 1)

    get categories_url

    flowers = category_json("flowers")
    assert_equal 1, flowers["productCount"]
    assert_equal 48.0, flowers["fromPrice"]
  end

  test "index shows zero products and no price for a category without active products" do
    Category.create!(name_en: "Toys", slug: "toys", position: 3)

    get categories_url

    assert_equal 0, category_json("toys")["productCount"]
    assert_nil category_json("toys")["fromPrice"]
  end

  test "index sends the lowest price as a number" do
    get categories_url

    assert_kind_of Numeric, category_json("cakes")["fromPrice"]
  end

  test "index takes the same number of queries however many categories exist" do
    5.times { |n| Category.create!(name_en: "Extra #{n}", slug: "extra-#{n}", position: 10 + n) }

    assert_queries_count(2) { get categories_url }
  end

  test "index returns null for missing Arabic text" do
    get categories_url

    cakes = response.parsed_body["data"].find { |category| category["slug"] == "cakes" }
    assert_nil cakes["nameAr"]
    assert_nil cakes["taglineAr"]
  end

  test "index returns an empty list when there are no categories" do
    ProductCategory.delete_all
    Category.delete_all

    get categories_url

    assert_response :success
    assert_equal [], response.parsed_body["data"]
  end

  private
    def category_json(slug)
      response.parsed_body["data"].find { |category| category["slug"] == slug }
    end
end
