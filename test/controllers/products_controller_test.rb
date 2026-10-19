require "test_helper"

class ProductsControllerTest < ActionDispatch::IntegrationTest
  # ---------- Response shape ----------

  test "index responds with JSON" do
    get products_url

    assert_response :success
    assert_equal "application/json", response.media_type
  end

  test "index returns data and meta keys only" do
    get products_url

    assert_equal %w[ data meta ], response.parsed_body.keys
  end

  test "index returns every card field for a product" do
    get products_url

    assert_equal(
      {
        "slug" => "forever-yours-gift-set",
        "nameEn" => "Forever Yours Gift Set",
        "nameAr" => "طقم هدايا للأبد لك",
        "category" => { "slug" => "flowers", "nameEn" => "Flowers", "nameAr" => "زهور" },
        "price" => 48.0,
        "ratingAverage" => 4.6,
        "reviewsCount" => 8,
        "image" => "/assets/images/pendant.webp",
        "inStock" => true
      },
      product_json("forever-yours-gift-set")
    )
  end

  test "index sends prices and ratings as numbers" do
    get products_url

    assert_kind_of Numeric, product_json("belgian-chocolate-box")["price"]
    assert_kind_of Numeric, product_json("belgian-chocolate-box")["ratingAverage"]
  end

  test "index returns null for a product without images" do
    get products_url

    assert_nil product_json("belgian-chocolate-box")["image"]
  end

  test "index marks out of stock products" do
    get products_url

    assert_equal false, product_json("cuddly-teddy-bear-classic")["inStock"]
  end

  # ---------- Filtering and order ----------

  test "index leaves out inactive products" do
    get products_url

    assert_not_includes slugs, products(:hidden_product).slug
  end

  test "index lists the newest products first" do
    products(:chocolate_box).update_column(:created_at, 2.days.ago)
    products(:gift_set).update_column(:created_at, 1.day.ago)
    products(:teddy_bear).update_column(:created_at, Time.current)

    get products_url

    assert_equal %w[ cuddly-teddy-bear-classic forever-yours-gift-set belgian-chocolate-box ], slugs
  end

  # ---------- Pagination ----------

  test "index defaults to the first page of 20" do
    get products_url

    assert_equal({ "page" => 1, "perPage" => 20, "totalCount" => 3, "totalPages" => 1 }, pagination_meta)
  end

  test "index splits products into pages" do
    get products_url, params: { perPage: 2 }
    first_page = slugs

    assert_equal 2, first_page.size
    assert_equal({ "page" => 1, "perPage" => 2, "totalCount" => 3, "totalPages" => 2 }, pagination_meta)

    get products_url, params: { perPage: 2, page: 2 }
    second_page = slugs

    assert_equal 1, second_page.size
    assert_equal 2, response.parsed_body.dig("meta", "page")
    assert_empty first_page & second_page, "a product appeared on both pages"
  end

  test "index returns an empty page past the last page" do
    get products_url, params: { perPage: 2, page: 5 }

    assert_response :success
    assert_equal [], response.parsed_body["data"]
    assert_equal 3, response.parsed_body.dig("meta", "totalCount")
  end

  test "index caps the page size at 50" do
    get products_url, params: { perPage: 500 }

    assert_equal 50, response.parsed_body.dig("meta", "perPage")
  end

  test "index falls back to defaults for invalid page values" do
    [ "0", "-1", "abc", "1.5", "" ].each do |value|
      get products_url, params: { page: value, perPage: value }

      assert_response :success
      assert_equal 1, response.parsed_body.dig("meta", "page"), "page=#{value.inspect}"
      assert_equal 20, response.parsed_body.dig("meta", "perPage"), "perPage=#{value.inspect}"
    end
  end

  test "index reads page numbers in base 10" do
    get products_url, params: { perPage: "010" }

    assert_equal 10, response.parsed_body.dig("meta", "perPage")
  end

  test "index returns an empty list when there are no active products" do
    Product.update_all(active: false)

    get products_url

    assert_equal [], response.parsed_body["data"]
    assert_equal({ "page" => 1, "perPage" => 20, "totalCount" => 0, "totalPages" => 0 }, pagination_meta)
  end

  # ---------- Sorting ----------

  test "index sorts by newest first when no sort is given" do
    products(:chocolate_box).update_column(:created_at, 2.days.ago)
    products(:teddy_bear).update_column(:created_at, 1.day.ago)
    products(:gift_set).update_column(:created_at, Time.current)

    get products_url

    assert_equal %w[ forever-yours-gift-set cuddly-teddy-bear-classic belgian-chocolate-box ], slugs
    assert_equal "latest", response.parsed_body.dig("meta", "sort")
  end

  test "index sorts by price from low to high" do
    get products_url, params: { sort: "price-asc" }

    assert_equal %w[ cuddly-teddy-bear-classic belgian-chocolate-box forever-yours-gift-set ], slugs
    assert_equal "price-asc", response.parsed_body.dig("meta", "sort")
  end

  test "index sorts by price from high to low" do
    get products_url, params: { sort: "price-desc" }

    assert_equal %w[ forever-yours-gift-set belgian-chocolate-box cuddly-teddy-bear-classic ], slugs
    assert_equal "price-desc", response.parsed_body.dig("meta", "sort")
  end

  test "index sorts by rating, with more reviews winning a tie" do
    products(:gift_set).update_columns(rating_average: 4.6, reviews_count: 8)
    products(:teddy_bear).update_columns(rating_average: 4.8, reviews_count: 3)
    products(:chocolate_box).update_columns(rating_average: 4.8, reviews_count: 214)

    get products_url, params: { sort: "rating" }

    assert_equal %w[ belgian-chocolate-box cuddly-teddy-bear-classic forever-yours-gift-set ], slugs
    assert_equal "rating", response.parsed_body.dig("meta", "sort")
  end

  test "index breaks price ties by newest id first" do
    products(:chocolate_box).update_column(:price, products(:teddy_bear).price)
    tied = [ products(:teddy_bear), products(:chocolate_box) ].sort_by(&:id).reverse.map(&:slug)

    get products_url, params: { sort: "price-asc" }

    assert_equal tied, slugs.first(2)
  end

  test "index keeps the same order for tied products on every request" do
    Product.update_all(price: 10)

    get products_url, params: { sort: "price-asc" }
    first_order = slugs
    get products_url, params: { sort: "price-asc" }

    assert_equal first_order, slugs
  end

  test "index falls back to newest first for an unknown sort" do
    [ "cheapest", "PRICE-ASC", "price; DROP TABLE products", "" ].each do |value|
      get products_url, params: { sort: value }

      assert_response :success
      assert_equal "latest", response.parsed_body.dig("meta", "sort"), "sort=#{value.inspect}"
    end
  end

  test "index sorts before splitting into pages" do
    get products_url, params: { sort: "price-desc", perPage: 1, page: 2 }

    assert_equal %w[ belgian-chocolate-box ], slugs
  end

  # ---------- Category filter ----------

  test "index filters by one category" do
    get products_url, params: { categories: "flowers" }

    assert_equal %w[ forever-yours-gift-set ], slugs
  end

  test "index includes products linked to a category as an extra category" do
    get products_url, params: { categories: "cakes" }

    assert_includes slugs, "forever-yours-gift-set"
    assert_equal %w[ belgian-chocolate-box cuddly-teddy-bear-classic forever-yours-gift-set ], slugs.sort
  end

  test "index matches products in any of several categories, listing each once" do
    get products_url, params: { categories: "flowers,cakes" }

    assert_equal %w[ belgian-chocolate-box cuddly-teddy-bear-classic forever-yours-gift-set ], slugs.sort
    assert_equal slugs.uniq, slugs
  end

  test "index counts only the filtered products" do
    get products_url, params: { categories: "flowers", perPage: 1 }

    assert_equal({ "page" => 1, "perPage" => 1, "totalCount" => 1, "totalPages" => 1 }, pagination_meta)
  end

  test "index counts a product in two selected categories once" do
    get products_url, params: { categories: "flowers,cakes" }

    assert_equal 3, response.parsed_body.dig("meta", "totalCount")
  end

  test "index still leaves out inactive products when filtering" do
    get products_url, params: { categories: "flowers" }

    assert_not_includes slugs, products(:hidden_product).slug
  end

  test "index returns an empty list for an unknown category" do
    get products_url, params: { categories: "balloons" }

    assert_response :success
    assert_equal [], slugs
    assert_equal 0, response.parsed_body.dig("meta", "totalCount")
  end

  test "index ignores unknown categories mixed with known ones" do
    get products_url, params: { categories: "balloons,flowers" }

    assert_equal %w[ forever-yours-gift-set ], slugs
  end

  test "index matches nothing for an inactive category" do
    ProductCategory.create!(product: products(:chocolate_box), category: categories(:hidden))

    get products_url, params: { categories: categories(:hidden).slug }

    assert_equal [], slugs
  end

  test "index ignores spaces, empty entries, letter case and repeats in the category list" do
    get products_url, params: { categories: " Flowers,, flowers ," }

    assert_equal %w[ forever-yours-gift-set ], slugs
    assert_equal [ "flowers" ], response.parsed_body.dig("meta", "filters", "categories")
  end

  test "index accepts repeated category parameters" do
    get products_url, params: { categories: %w[ flowers cakes ] }

    assert_equal 3, slugs.size
  end

  test "index filters, then sorts, then splits into pages" do
    get products_url, params: { categories: "cakes", sort: "price-asc", perPage: 2 }

    assert_equal %w[ cuddly-teddy-bear-classic belgian-chocolate-box ], slugs
    assert_equal({ "page" => 1, "perPage" => 2, "totalCount" => 3, "totalPages" => 2 }, pagination_meta)
  end

  test "index reports the applied categories in meta" do
    get products_url, params: { categories: "flowers,cakes" }

    assert_equal %w[ flowers cakes ], response.parsed_body.dig("meta", "filters", "categories")
  end

  test "index reports no categories when none are selected" do
    get products_url

    assert_equal [], response.parsed_body.dig("meta", "filters", "categories")
  end

  test "index uses at most 20 category values" do
    many = (1..30).map { |n| "category-#{n}" }

    get products_url, params: { categories: many.join(",") }

    assert_equal 20, response.parsed_body.dig("meta", "filters", "categories").size
  end

  # ---------- Occasion filter ----------

  test "index filters by one occasion" do
    get products_url, params: { occasions: "birthday" }

    assert_equal %w[ cuddly-teddy-bear-classic forever-yours-gift-set ], slugs.sort
  end

  test "index matches products for any of several occasions, listing each once" do
    get products_url, params: { occasions: "birthday,valentines-day" }

    assert_equal %w[ cuddly-teddy-bear-classic forever-yours-gift-set ], slugs.sort
    assert_equal 2, response.parsed_body.dig("meta", "totalCount")
  end

  test "index returns an empty list for an occasion with no products" do
    get products_url, params: { occasions: "graduation" }

    assert_equal [], slugs
  end

  test "index returns an empty list for an unknown occasion" do
    get products_url, params: { occasions: "eid" }

    assert_response :success
    assert_equal [], slugs
  end

  test "index ignores unknown occasions mixed with known ones" do
    get products_url, params: { occasions: "eid,valentines-day" }

    assert_equal %w[ forever-yours-gift-set ], slugs
  end

  test "index matches nothing for an inactive occasion" do
    ProductOccasion.create!(product: products(:chocolate_box), occasion: occasions(:hidden))

    get products_url, params: { occasions: occasions(:hidden).slug }

    assert_equal [], slugs
  end

  test "index still leaves out inactive products when filtering by occasion" do
    ProductOccasion.create!(product: products(:hidden_product), occasion: occasions(:birthday))

    get products_url, params: { occasions: "birthday" }

    assert_not_includes slugs, products(:hidden_product).slug
  end

  test "index reports the applied occasions in meta" do
    get products_url, params: { occasions: " Birthday,, birthday" }

    assert_equal [ "birthday" ], response.parsed_body.dig("meta", "filters", "occasions")
  end

  test "index reports no occasions when none are selected" do
    get products_url

    assert_equal [], response.parsed_body.dig("meta", "filters", "occasions")
  end

  # ---------- Combined filters ----------

  test "index requires a product to match every filter used" do
    get products_url, params: { categories: "cakes", occasions: "birthday" }

    assert_equal %w[ cuddly-teddy-bear-classic forever-yours-gift-set ], slugs.sort
    assert_equal 2, response.parsed_body.dig("meta", "totalCount")
  end

  test "index narrows further as filters are added" do
    get products_url, params: { categories: "flowers", occasions: "birthday" }

    assert_equal %w[ forever-yours-gift-set ], slugs
  end

  test "index returns nothing when no product matches every filter" do
    get products_url, params: { categories: "flowers", occasions: "graduation" }

    assert_equal [], slugs
  end

  # ---------- Gender filter ----------

  test "index shows women's and unisex products for women" do
    create_product("mens-watch", gender: "men")

    get products_url, params: { gender: "women" }

    assert_equal %w[ belgian-chocolate-box cuddly-teddy-bear-classic forever-yours-gift-set ], slugs.sort
  end

  test "index shows men's and unisex products for men" do
    create_product("mens-watch", gender: "men")

    get products_url, params: { gender: "men" }

    assert_equal %w[ belgian-chocolate-box cuddly-teddy-bear-classic mens-watch ], slugs.sort
  end

  test "index shows only unisex products for unisex" do
    create_product("mens-watch", gender: "men")

    get products_url, params: { gender: "unisex" }

    assert_equal %w[ belgian-chocolate-box cuddly-teddy-bear-classic ], slugs.sort
  end

  test "index shows every product when no gender is given" do
    create_product("mens-watch", gender: "men")

    [ nil, "", "   " ].each do |value|
      get products_url, params: { gender: value }

      assert_equal 4, slugs.size, "gender=#{value.inspect}"
    end
  end

  test "index matches nothing for an unknown gender" do
    [ "other", "men,women" ].each do |value|
      get products_url, params: { gender: value }

      assert_equal [], slugs, "gender=#{value.inspect}"
    end
  end

  test "index ignores spaces and letter case in the gender" do
    get products_url, params: { gender: " Women " }

    assert_equal 3, slugs.size
    assert_equal "women", response.parsed_body.dig("meta", "filters", "gender")
  end

  test "index reports the selected gender in meta, without the added unisex" do
    get products_url, params: { gender: "men" }

    assert_equal "men", response.parsed_body.dig("meta", "filters", "gender")
  end

  # ---------- Age group filter ----------

  test "index filters by one age group" do
    get products_url, params: { ageGroups: "0-6" }

    assert_equal %w[ cuddly-teddy-bear-classic ], slugs
  end

  test "index uses 18-plus for the 18+ age group" do
    get products_url, params: { ageGroups: "18-plus" }

    assert_equal %w[ forever-yours-gift-set ], slugs
  end

  test "index does not accept 18+ as an age group value" do
    get products_url, params: { ageGroups: "18+" }

    assert_equal [], slugs
  end

  test "index matches products in any of several age groups" do
    get products_url, params: { ageGroups: "0-6,18-plus" }

    assert_equal %w[ cuddly-teddy-bear-classic forever-yours-gift-set ], slugs.sort
  end

  test "index leaves products without an age group out of age filters" do
    assert_nil products(:chocolate_box).age_group

    get products_url, params: { ageGroups: "0-6,6-18,18-plus" }

    assert_not_includes slugs, "belgian-chocolate-box"
  end

  test "index matches nothing for an unknown age group" do
    get products_url, params: { ageGroups: "teen" }

    assert_equal [], slugs
  end

  test "index reports the selected age groups in meta" do
    get products_url, params: { ageGroups: "18-PLUS, 0-6" }

    assert_equal %w[ 18-plus 0-6 ], response.parsed_body.dig("meta", "filters", "ageGroups")
  end

  test "index reports no gender or age groups when none are selected" do
    get products_url

    assert_nil response.parsed_body.dig("meta", "filters", "gender")
    assert_equal [], response.parsed_body.dig("meta", "filters", "ageGroups")
  end

  # ---------- All filters together ----------

  test "index combines category, occasion, gender and age group filters" do
    get products_url, params: { categories: "cakes", occasions: "birthday", gender: "women", ageGroups: "0-6" }

    assert_equal %w[ cuddly-teddy-bear-classic ], slugs
    assert_equal 1, response.parsed_body.dig("meta", "totalCount")
  end

  # ---------- Details ----------

  test "show responds with JSON in a data key" do
    get product_url("forever-yours-gift-set")

    assert_response :success
    assert_equal "application/json", response.media_type
    assert_equal [ "data" ], response.parsed_body.keys
  end

  test "show returns every details field for a product" do
    get product_url("forever-yours-gift-set")

    assert_equal(
      {
        "slug" => "forever-yours-gift-set",
        "nameEn" => "Forever Yours Gift Set",
        "nameAr" => "طقم هدايا للأبد لك",
        "category" => { "slug" => "flowers", "nameEn" => "Flowers", "nameAr" => "زهور" },
        "price" => 48.0,
        "ratingAverage" => 4.6,
        "reviewsCount" => 8,
        "image" => "/assets/images/pendant.webp",
        "inStock" => true,
        "descriptionEn" => "A rose gold heart pendant, red roses and Belgian chocolates in one box.",
        "descriptionAr" => "قلادة قلب من الذهب الوردي وورود حمراء وشوكولاتة بلجيكية في علبة واحدة.",
        "stock" => 6,
        "images" => [ "/assets/images/pendant.webp", "/assets/images/flowers.jpg" ],
        "occasions" => [
          { "slug" => "valentines-day", "nameEn" => "Valentine's Day", "nameAr" => "عيد الحب" },
          { "slug" => "birthday", "nameEn" => "Birthday", "nameAr" => nil }
        ]
      },
      response.parsed_body["data"]
    )
  end

  test "show returns empty lists for a product without images or occasions" do
    get product_url("belgian-chocolate-box")

    details = response.parsed_body["data"]
    assert_equal [], details["images"]
    assert_equal [], details["occasions"]
    assert_nil details["descriptionEn"]
  end

  test "show leaves inactive occasions out of the chips" do
    ProductOccasion.create!(product: products(:gift_set), occasion: occasions(:hidden))

    get product_url("forever-yours-gift-set")

    chips = response.parsed_body.dig("data", "occasions").map { |occasion| occasion["slug"] }
    assert_not_includes chips, occasions(:hidden).slug
  end

  test "show finds a product whatever the letter case of the slug" do
    get product_url("Forever-Yours-Gift-Set")

    assert_response :success
    assert_equal "forever-yours-gift-set", response.parsed_body.dig("data", "slug")
  end

  test "show returns not found for an unknown slug" do
    get product_url("does-not-exist")

    assert_response :not_found
    assert_equal "application/json", response.media_type
    assert_equal({ "error" => { "code" => "not_found", "message" => "Product not found" } }, response.parsed_body)
  end

  test "show returns not found for an inactive product" do
    get product_url(products(:hidden_product).slug)

    assert_response :not_found
    assert_equal "not_found", response.parsed_body.dig("error", "code")
  end

  private
    def create_product(slug, gender: "unisex", age_group: nil)
      product = Product.new(name_en: slug.titleize, slug: slug, price: 10, gender: gender, age_group: age_group)
      product.product_categories.build(category: categories(:flowers), primary_category: true)
      product.save!
      product
    end

    def slugs
      response.parsed_body["data"].map { |product| product["slug"] }
    end

    def pagination_meta
      response.parsed_body["meta"].slice("page", "perPage", "totalCount", "totalPages")
    end

    def product_json(slug)
      response.parsed_body["data"].find { |product| product["slug"] == slug }
    end
end
