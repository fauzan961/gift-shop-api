require "test_helper"

class CategoryTest < ActiveSupport::TestCase
  # ---------- Baseline ----------

  test "is valid with only a name and slug" do
    assert build_category.valid?
  end

  test "fixtures are valid" do
    Category.find_each do |category|
      assert category.valid?, "#{category.slug}: #{category.errors.full_messages.to_sentence}"
    end
  end

  # ---------- English name ----------

  test "requires an English name" do
    assert_invalid build_category(name_en: nil), :name_en, :blank
    assert_invalid build_category(name_en: "   "), :name_en, :blank
  end

  test "requires a unique English name" do
    assert_invalid build_category(name_en: categories(:flowers).name_en), :name_en, :taken
  end

  test "limits the English name to 50 characters" do
    assert build_category(name_en: "a" * 50).valid?
    assert_invalid build_category(name_en: "a" * 51), :name_en, :too_long
  end

  # ---------- Arabic name ----------

  test "does not require an Arabic name" do
    assert build_category(name_ar: nil).valid?
  end

  test "allows many categories without an Arabic name" do
    assert_nil categories(:cakes).name_ar
    assert build_category(name_ar: "   ").save
  end

  test "requires a unique Arabic name when present" do
    assert_invalid build_category(name_ar: categories(:flowers).name_ar), :name_ar, :taken
  end

  test "limits the Arabic name to 50 characters, not bytes" do
    assert build_category(name_ar: "ز" * 50).valid?
    assert_invalid build_category(name_ar: "ز" * 51), :name_ar, :too_long
  end

  # ---------- Slug ----------

  test "requires a slug" do
    assert_invalid build_category(slug: nil), :slug, :blank
    assert_invalid build_category(slug: "   "), :slug, :blank
  end

  test "requires a unique slug" do
    assert_invalid build_category(slug: categories(:flowers).slug), :slug, :taken
  end

  test "limits the slug to 60 characters" do
    assert build_category(slug: "a" * 60).valid?
    assert_invalid build_category(slug: "a" * 61), :slug, :too_long
  end

  test "accepts lowercase letters, numbers and single hyphens in the slug" do
    %w[ toys gift-hampers top-10-gifts 2026 ].each do |slug|
      assert build_category(slug: slug).valid?, "expected #{slug.inspect} to be valid"
    end
  end

  test "rejects badly formatted slugs" do
    [ "gift hampers", "gift--hampers", "-toys", "toys-", "toys_box", "toys!", "زهور" ].each do |slug|
      assert_invalid build_category(slug: slug), :slug, :invalid
    end
  end

  # ---------- Taglines ----------

  test "does not require taglines" do
    assert build_category(tagline_en: nil, tagline_ar: nil).valid?
  end

  test "limits taglines to 120 characters" do
    assert build_category(tagline_en: "a" * 120, tagline_ar: "ز" * 120).valid?
    assert_invalid build_category(tagline_en: "a" * 121), :tagline_en, :too_long
    assert_invalid build_category(tagline_ar: "ز" * 121), :tagline_ar, :too_long
  end

  # ---------- Position ----------

  test "defaults position to 0" do
    assert_equal 0, Category.new.position
  end

  test "requires position to be a whole number of 0 or more" do
    assert_invalid build_category(position: nil), :position, :not_a_number
    assert_invalid build_category(position: -1), :position, :greater_than_or_equal_to
    assert_invalid build_category(position: 1.5), :position, :not_an_integer
  end

  # ---------- Active ----------

  test "defaults active to true" do
    assert Category.new.active
  end

  test "allows active to be true or false but not empty" do
    assert build_category(active: false).valid?
    assert_invalid build_category(active: nil), :active, :inclusion
  end

  # ---------- Input cleaning ----------

  test "strips spaces from names and taglines" do
    category = build_category(name_en: "  Toys  ", name_ar: "  ألعاب  ", tagline_en: "  Plush  ", tagline_ar: "  دمى  ")

    assert_equal "Toys", category.name_en
    assert_equal "ألعاب", category.name_ar
    assert_equal "Plush", category.tagline_en
    assert_equal "دمى", category.tagline_ar
  end

  test "stores blank Arabic name and taglines as nil" do
    category = build_category(name_ar: "   ", tagline_en: "", tagline_ar: "  ")

    assert_nil category.name_ar
    assert_nil category.tagline_en
    assert_nil category.tagline_ar
  end

  test "strips and lowercases the slug" do
    assert_equal "gift-hampers", build_category(slug: "  Gift-Hampers  ").slug
  end

  test "still rejects a cleaned slug that has spaces inside" do
    assert_invalid build_category(slug: "Gift Hampers"), :slug, :invalid
  end

  # ---------- Scopes ----------

  test "active leaves out inactive categories" do
    assert_includes Category.active, categories(:flowers)
    assert_not_includes Category.active, categories(:hidden)
  end

  test "ordered sorts by position" do
    assert_equal %w[ hidden-category flowers cakes ], Category.ordered.pluck(:slug)
  end

  test "ordered breaks position ties by id" do
    first = Category.create!(name_en: "First", slug: "first", position: 5)
    second = Category.create!(name_en: "Second", slug: "second", position: 5)

    assert_equal [ first, second ], Category.ordered.where(position: 5).to_a
  end

  # ---------- Database rules ----------
  # These skip the model validations to prove the database rejects bad data
  # on its own, for example from the console or bulk inserts.

  test "database rejects a badly formatted slug" do
    assert_raises(ActiveRecord::StatementInvalid) do
      build_category(slug: "bad slug").save(validate: false)
    end
  end

  test "database rejects a duplicate English name" do
    assert_raises(ActiveRecord::RecordNotUnique) do
      build_category(name_en: categories(:flowers).name_en).save(validate: false)
    end
  end

  test "database rejects a duplicate slug" do
    assert_raises(ActiveRecord::RecordNotUnique) do
      build_category(slug: categories(:flowers).slug).save(validate: false)
    end
  end

  test "database rejects a missing English name" do
    assert_raises(ActiveRecord::NotNullViolation) do
      build_category(name_en: nil).save(validate: false)
    end
  end

  private
    def build_category(**attributes)
      Category.new({ name_en: "Toys", slug: "toys" }.merge(attributes))
    end

    def assert_invalid(category, attribute, error_type)
      assert_not category.valid?, "expected #{attribute} #{error_type} error, but the category was valid"
      assert category.errors.of_kind?(attribute, error_type),
             "expected #{attribute} #{error_type} error, got #{category.errors.details[attribute]}"
    end
end
