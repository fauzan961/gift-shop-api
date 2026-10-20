require "test_helper"

class ProductTest < ActiveSupport::TestCase
  # ---------- Baseline ----------

  test "is valid with a name, slug, price and one main category" do
    assert build_product.valid?
  end

  test "fixtures are valid" do
    Product.find_each do |product|
      assert product.valid?, "#{product.slug}: #{product.errors.full_messages.to_sentence}"
    end
  end

  # ---------- English name ----------

  test "requires an English name" do
    assert_invalid build_product(name_en: nil), :name_en, :blank
    assert_invalid build_product(name_en: "   "), :name_en, :blank
  end

  test "allows two products with the same English name" do
    assert build_product(name_en: products(:gift_set).name_en).valid?
  end

  test "limits the English name to 100 characters" do
    assert build_product(name_en: "a" * 100).valid?
    assert_invalid build_product(name_en: "a" * 101), :name_en, :too_long
  end

  # ---------- Arabic name ----------

  test "does not require an Arabic name" do
    assert build_product(name_ar: nil).valid?
  end

  test "limits the Arabic name to 100 characters, not bytes" do
    assert build_product(name_ar: "ه" * 100).valid?
    assert_invalid build_product(name_ar: "ه" * 101), :name_ar, :too_long
  end

  # ---------- Slug ----------

  test "requires a slug" do
    assert_invalid build_product(slug: nil), :slug, :blank
    assert_invalid build_product(slug: "   "), :slug, :blank
  end

  test "requires a unique slug" do
    assert_invalid build_product(slug: products(:gift_set).slug), :slug, :taken
  end

  test "limits the slug to 120 characters" do
    assert build_product(slug: "a" * 120).valid?
    assert_invalid build_product(slug: "a" * 121), :slug, :too_long
  end

  test "accepts lowercase letters, numbers and single hyphens in the slug" do
    %w[ roses red-rose-bouquet gift-set-2026 2026 ].each do |slug|
      assert build_product(slug: slug).valid?, "expected #{slug.inspect} to be valid"
    end
  end

  test "rejects badly formatted slugs" do
    [ "red roses", "red--roses", "-roses", "roses-", "red_roses", "roses!", "ورود" ].each do |slug|
      assert_invalid build_product(slug: slug), :slug, :invalid
    end
  end

  # ---------- Descriptions ----------

  test "does not require descriptions" do
    assert build_product(description_en: nil, description_ar: nil).valid?
  end

  test "limits descriptions to 2000 characters" do
    assert build_product(description_en: "a" * 2000, description_ar: "ه" * 2000).valid?
    assert_invalid build_product(description_en: "a" * 2001), :description_en, :too_long
    assert_invalid build_product(description_ar: "ه" * 2001), :description_ar, :too_long
  end

  # ---------- Price ----------

  test "requires a price" do
    assert_invalid build_product(price: nil), :price, :not_a_number
  end

  test "requires a price greater than zero" do
    assert build_product(price: "0.001").valid?
    assert_invalid build_product(price: 0), :price, :greater_than
    assert_invalid build_product(price: -1), :price, :greater_than
  end

  test "limits the price to 10,000 KWD" do
    assert build_product(price: Product::MAX_PRICE).valid?
    assert_invalid build_product(price: "10000.001"), :price, :less_than_or_equal_to
  end

  test "keeps prices to three decimal places" do
    assert_equal BigDecimal("18.5"), build_product(price: "18.500").price
    assert_equal BigDecimal("18.501"), build_product(price: "18.5006").price
  end

  # ---------- Gender ----------

  test "defaults gender to unisex" do
    assert_equal "unisex", Product.new.gender
  end

  test "accepts men, women and unisex" do
    Product::GENDERS.each do |gender|
      assert build_product(gender: gender).valid?, "expected #{gender.inspect} to be valid"
    end
  end

  test "rejects any other gender" do
    assert_invalid build_product(gender: "other"), :gender, :inclusion
    assert_invalid build_product(gender: "Men"), :gender, :inclusion
    assert_invalid build_product(gender: nil), :gender, :inclusion
  end

  # ---------- Age group ----------

  test "does not require an age group" do
    assert build_product(age_group: nil).valid?
  end

  test "accepts the three age groups" do
    Product::AGE_GROUPS.each do |age_group|
      assert build_product(age_group: age_group).valid?, "expected #{age_group.inspect} to be valid"
    end
  end

  test "rejects any other age group" do
    assert_invalid build_product(age_group: "teen"), :age_group, :inclusion
    assert_invalid build_product(age_group: "0-6 yrs"), :age_group, :inclusion
  end

  # ---------- Stock ----------

  test "defaults stock to 0" do
    assert_equal 0, Product.new.stock
  end

  test "requires stock to be a whole number of 0 or more" do
    assert_invalid build_product(stock: nil), :stock, :not_a_number
    assert_invalid build_product(stock: -1), :stock, :greater_than_or_equal_to
    assert_invalid build_product(stock: 1.5), :stock, :not_an_integer
  end

  test "is in stock only when stock is above zero" do
    assert products(:gift_set).in_stock?
    assert_not products(:teddy_bear).in_stock?
  end

  # ---------- Rating and review count ----------

  test "defaults rating average and review count to 0" do
    product = Product.new

    assert_equal 0, product.rating_average
    assert_equal 0, product.reviews_count
  end

  test "keeps the rating average between 0 and 5" do
    assert build_product(rating_average: 5).valid?
    assert_invalid build_product(rating_average: "5.1"), :rating_average, :less_than_or_equal_to
    assert_invalid build_product(rating_average: "-0.1"), :rating_average, :greater_than_or_equal_to
  end

  test "requires the review count to be a whole number of 0 or more" do
    assert_invalid build_product(reviews_count: -1), :reviews_count, :greater_than_or_equal_to
    assert_invalid build_product(reviews_count: 1.5), :reviews_count, :not_an_integer
  end

  # ---------- Active ----------

  test "defaults active to true" do
    assert Product.new.active
  end

  test "allows active to be true or false but not empty" do
    assert build_product(active: false).valid?
    assert_invalid build_product(active: nil), :active, :inclusion
  end

  # ---------- Input cleaning ----------

  test "strips spaces from names and descriptions" do
    product = build_product(name_en: "  Roses  ", name_ar: "  ورود  ", description_en: "  Fresh  ", description_ar: "  طازجة  ")

    assert_equal "Roses", product.name_en
    assert_equal "ورود", product.name_ar
    assert_equal "Fresh", product.description_en
    assert_equal "طازجة", product.description_ar
  end

  test "stores blank Arabic name and descriptions as nil" do
    product = build_product(name_ar: "   ", description_en: "", description_ar: "  ")

    assert_nil product.name_ar
    assert_nil product.description_en
    assert_nil product.description_ar
  end

  test "strips and lowercases the slug" do
    assert_equal "red-roses", build_product(slug: "  Red-Roses  ").slug
  end

  # ---------- Main category ----------

  test "requires a main category" do
    product = Product.new(name_en: "Roses", slug: "roses", price: 10)
    product.product_categories.build(category: categories(:flowers), primary_category: false)

    assert_main_category_error product
  end

  test "requires at least one category link" do
    product = Product.new(name_en: "Roses", slug: "roses", price: 10)

    assert_main_category_error product
  end

  test "rejects more than one main category" do
    product = build_product
    product.product_categories.build(category: categories(:cakes), primary_category: true)

    assert_main_category_error product
  end

  test "allows extra categories alongside the main one" do
    product = build_product
    product.product_categories.build(category: categories(:cakes), primary_category: false)

    assert product.valid?
  end

  test "ignores a main category link that is marked for deletion" do
    product = build_product
    product.product_categories.first.mark_for_destruction

    assert_main_category_error product
  end

  # ---------- Associations ----------

  test "saves a new product together with its links and images" do
    product = build_product
    product.product_categories.build(category: categories(:cakes))
    product.product_images.build(image: "/assets/images/flowers.jpg")
    product.product_occasions.build(occasion: occasions(:birthday))

    assert product.save
    assert_equal 2, product.product_categories.count
    assert_equal 1, product.product_images.count
    assert_equal 1, product.product_occasions.count
  end

  test "lists all its categories" do
    assert_equal %w[ cakes flowers ], products(:gift_set).categories.order(:slug).pluck(:slug)
  end

  test "returns its main category" do
    assert_equal categories(:flowers), products(:gift_set).primary_category
  end

  test "lists its occasions" do
    assert_equal %w[ birthday valentines-day ], products(:gift_set).occasions.order(:slug).pluck(:slug)
  end

  test "orders images by position, not by insertion order" do
    images = products(:gift_set).product_images.map(&:image)

    assert_equal [ "/assets/images/pendant.webp", "/assets/images/flowers.jpg" ], images
  end

  test "uses the lowest positioned image as the cover image" do
    assert_equal product_images(:gift_set_pendant_image), products(:gift_set).cover_image
  end

  test "has no cover image when it has no images" do
    assert_nil products(:chocolate_box).cover_image
  end

  test "deleting a product removes its links and images" do
    product = products(:gift_set)
    product.destroy

    assert_equal 0, ProductCategory.where(product_id: product.id).count
    assert_equal 0, ProductImage.where(product_id: product.id).count
    assert_equal 0, ProductOccasion.where(product_id: product.id).count
  end

  # ---------- Related products ----------

  test "related products put category matches before occasion matches" do
    kites = create_category("kites")
    loner = create_related_product("lonely-kite", category: kites)
    loner.product_occasions.create!(occasion: occasions(:graduation))
    category_match = create_related_product("box-kite", category: kites, rating: 1)
    occasion_match = create_related_product("paper-hat", category: create_category("hats"), rating: 5)
    occasion_match.product_occasions.create!(occasion: occasions(:graduation))

    assert_equal [ category_match, occasion_match ], loner.related_products.first(2)
  end

  test "related products put occasion matches before the top rated fill" do
    loner = create_related_product("lonely-kite", category: create_category("kites"))
    loner.product_occasions.create!(occasion: occasions(:graduation))
    occasion_match = create_related_product("paper-hat", category: create_category("hats"), rating: 1)
    occasion_match.product_occasions.create!(occasion: occasions(:graduation))

    related = loner.related_products

    assert_equal occasion_match, related.first
    assert_equal "forever-yours-gift-set", related.second.slug
  end

  test "related products rank products within a tier by rating" do
    # Both share only Cakes with the chocolate box, and the gift set is rated higher.
    assert_equal %w[ forever-yours-gift-set cuddly-teddy-bear-classic ], products(:chocolate_box).related_products.map(&:slug)
  end

  test "related products list a product sharing several categories only once" do
    # The gift set is in Flowers and Cakes, and so is this bouquet.
    bouquet = create_related_product("cake-bouquet", category: categories(:flowers), rating: 5)
    bouquet.product_categories.create!(category: categories(:cakes))

    related = products(:gift_set).related_products

    assert_equal 1, related.count(bouquet)
  end

  test "related products list a product sharing several occasions only once" do
    # The gift set suits Valentine's Day and Birthday, and so does this card.
    card = create_related_product("love-card", category: create_category("cards"), rating: 5)
    card.product_occasions.create!(occasion: occasions(:valentines_day))
    card.product_occasions.create!(occasion: occasions(:birthday))

    related = products(:gift_set).related_products

    assert_equal 1, related.count(card)
  end

  test "related products list a product matching several tiers only once" do
    # The teddy bear shares Cakes and Birthday with the gift set.
    related = products(:gift_set).related_products

    assert_equal related.uniq, related
    assert_equal 1, related.count { |product| product.slug == "cuddly-teddy-bear-classic" }
  end

  test "related products never include the product itself or inactive products" do
    related = products(:gift_set).related_products

    assert_not_includes related, products(:gift_set)
    assert_not_includes related, products(:hidden_product)
  end

  test "related products return at most four by default" do
    5.times { |n| create_related_product("rose-bunch-#{n}", category: categories(:flowers), rating: 3) }

    related = products(:gift_set).related_products

    assert_equal 4, related.size
    assert related.all? { |product| product.slug.start_with?("rose-bunch-") }, "expected the higher rated rose bunches"
  end

  test "related products accept a different limit" do
    assert_equal 1, products(:gift_set).related_products(limit: 1).size
  end

  test "related products fill with top rated products when nothing is shared" do
    loner = create_related_product("lonely-kite", category: create_category("kites"))

    related = loner.related_products

    assert_equal "forever-yours-gift-set", related.first.slug
    assert_equal 3, related.size
    assert_not_includes related, loner
  end

  test "related products put real matches before the fill, without repeats" do
    kites = create_category("kites")
    loner = create_related_product("lonely-kite", category: kites)
    match = create_related_product("box-kite", category: kites, rating: 1)

    related = loner.related_products

    assert_equal match, related.first
    assert_equal 4, related.size
    assert_equal related.uniq, related
  end

  test "related products ignore shared inactive categories" do
    loner = create_related_product("lonely-kite", category: create_category("kites"))
    loner.product_categories.create!(category: categories(:hidden))
    other = create_related_product("paper-kite", category: create_category("paper"))
    other.product_categories.create!(category: categories(:hidden))

    assert_equal "forever-yours-gift-set", loner.related_products.first.slug
  end

  test "related products ignore shared inactive occasions" do
    loner = create_related_product("lonely-kite", category: create_category("kites"))
    loner.product_occasions.create!(occasion: occasions(:hidden))
    other = create_related_product("paper-kite", category: create_category("paper"))
    other.product_occasions.create!(occasion: occasions(:hidden))

    assert_equal "forever-yours-gift-set", loner.related_products.first.slug
  end

  test "related products are empty when no other active product exists" do
    Product.where.not(id: products(:gift_set).id).update_all(active: false)

    assert_equal [], products(:gift_set).related_products
  end

  # ---------- Scopes ----------

  test "active leaves out inactive products" do
    assert_includes Product.active, products(:gift_set)
    assert_not_includes Product.active, products(:hidden_product)
  end

  # ---------- Database rules ----------
  # These skip the model validations to prove the database rejects bad data
  # on its own, for example from the console or bulk inserts.

  test "database rejects a badly formatted slug" do
    assert_raises(ActiveRecord::CheckViolation) { build_product(slug: "bad slug").save(validate: false) }
  end

  test "database rejects a duplicate slug" do
    assert_raises(ActiveRecord::RecordNotUnique) do
      build_product(slug: products(:gift_set).slug).save(validate: false)
    end
  end

  test "database rejects a price of zero" do
    assert_raises(ActiveRecord::CheckViolation) { build_product(price: 0).save(validate: false) }
  end

  test "database rejects a price with too many digits" do
    assert_raises(ActiveRecord::RangeError) { build_product(price: 10_000_000).save(validate: false) }
  end

  test "database rejects an unknown gender" do
    assert_raises(ActiveRecord::CheckViolation) { build_product(gender: "other").save(validate: false) }
  end

  test "database rejects negative stock" do
    assert_raises(ActiveRecord::CheckViolation) { build_product(stock: -1).save(validate: false) }
  end

  test "database rejects a rating above 5" do
    assert_raises(ActiveRecord::CheckViolation) { build_product(rating_average: "5.1").save(validate: false) }
  end

  test "database rejects a negative review count" do
    assert_raises(ActiveRecord::CheckViolation) { build_product(reviews_count: -1).save(validate: false) }
  end

  test "database rejects a missing English name" do
    assert_raises(ActiveRecord::NotNullViolation) { build_product(name_en: nil).save(validate: false) }
  end

  test "database rejects two main categories for one product" do
    product = build_product
    product.product_categories.build(category: categories(:cakes), primary_category: true)

    assert_raises(ActiveRecord::RecordNotUnique) { product.save(validate: false) }
  end

  private
    def build_product(**attributes)
      Product.new({ name_en: "Red Roses", slug: "red-roses", price: 10 }.merge(attributes)).tap do |product|
        product.product_categories.build(category: categories(:flowers), primary_category: true)
      end
    end

    def assert_invalid(product, attribute, error_type)
      assert_not product.valid?, "expected #{attribute} #{error_type} error, but the product was valid"
      assert product.errors.of_kind?(attribute, error_type),
             "expected #{attribute} #{error_type} error, got #{product.errors.details[attribute]}"
    end

    def create_category(slug)
      Category.create!(name_en: slug.titleize, slug: slug)
    end

    def create_related_product(slug, category:, rating: 0)
      product = Product.new(name_en: slug.titleize, slug: slug, price: 10, rating_average: rating)
      product.product_categories.build(category: category, primary_category: true)
      product.save!
      product
    end

    def assert_main_category_error(product)
      assert_not product.valid?, "expected a main category error, but the product was valid"
      assert_includes product.errors[:product_categories], "must include exactly one primary category"
    end
end
