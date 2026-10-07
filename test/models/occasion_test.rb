require "test_helper"

class OccasionTest < ActiveSupport::TestCase
  # ---------- Baseline ----------

  test "is valid with only a name and slug" do
    assert build_occasion.valid?
  end

  test "fixtures are valid" do
    Occasion.find_each do |occasion|
      assert occasion.valid?, "#{occasion.slug}: #{occasion.errors.full_messages.to_sentence}"
    end
  end

  # ---------- English name ----------

  test "requires an English name" do
    assert_invalid build_occasion(name_en: nil), :name_en, :blank
    assert_invalid build_occasion(name_en: "   "), :name_en, :blank
  end

  test "requires a unique English name" do
    assert_invalid build_occasion(name_en: occasions(:valentines_day).name_en), :name_en, :taken
  end

  test "limits the English name to 50 characters" do
    assert build_occasion(name_en: "a" * 50).valid?
    assert_invalid build_occasion(name_en: "a" * 51), :name_en, :too_long
  end

  # ---------- Arabic name ----------

  test "does not require an Arabic name" do
    assert build_occasion(name_ar: nil).valid?
  end

  test "allows many occasions without an Arabic name" do
    assert_nil occasions(:birthday).name_ar
    assert build_occasion(name_ar: "   ").save
  end

  test "requires a unique Arabic name when present" do
    assert_invalid build_occasion(name_ar: occasions(:valentines_day).name_ar), :name_ar, :taken
  end

  test "limits the Arabic name to 50 characters, not bytes" do
    assert build_occasion(name_ar: "ع" * 50).valid?
    assert_invalid build_occasion(name_ar: "ع" * 51), :name_ar, :too_long
  end

  # ---------- Slug ----------

  test "requires a slug" do
    assert_invalid build_occasion(slug: nil), :slug, :blank
    assert_invalid build_occasion(slug: "   "), :slug, :blank
  end

  test "requires a unique slug" do
    assert_invalid build_occasion(slug: occasions(:valentines_day).slug), :slug, :taken
  end

  test "limits the slug to 60 characters" do
    assert build_occasion(slug: "a" * 60).valid?
    assert_invalid build_occasion(slug: "a" * 61), :slug, :too_long
  end

  test "accepts lowercase letters, numbers and single hyphens in the slug" do
    %w[ eid eid-al-fitr national-day-2027 2027 ].each do |slug|
      assert build_occasion(slug: slug).valid?, "expected #{slug.inspect} to be valid"
    end
  end

  test "rejects badly formatted slugs" do
    [ "eid al fitr", "eid--al-fitr", "-eid", "eid-", "eid_al_fitr", "eid!", "عيد" ].each do |slug|
      assert_invalid build_occasion(slug: slug), :slug, :invalid
    end
  end

  # ---------- Taglines ----------

  test "does not require taglines" do
    assert build_occasion(tagline_en: nil, tagline_ar: nil).valid?
  end

  test "limits taglines to 120 characters" do
    assert build_occasion(tagline_en: "a" * 120, tagline_ar: "ع" * 120).valid?
    assert_invalid build_occasion(tagline_en: "a" * 121), :tagline_en, :too_long
    assert_invalid build_occasion(tagline_ar: "ع" * 121), :tagline_ar, :too_long
  end

  # ---------- Date ----------

  test "does not require a date" do
    assert build_occasion(occurs_on: nil).valid?
  end

  test "upcoming date returns a future date" do
    occasion = build_occasion(occurs_on: Date.current + 1)
    assert_equal Date.current + 1, occasion.upcoming_date
  end

  test "upcoming date returns today's date" do
    occasion = build_occasion(occurs_on: Date.current)
    assert_equal Date.current, occasion.upcoming_date
  end

  test "upcoming date hides a past date" do
    assert_nil build_occasion(occurs_on: Date.current - 1).upcoming_date
  end

  test "upcoming date is empty when there is no date" do
    assert_nil build_occasion(occurs_on: nil).upcoming_date
  end

  test "upcoming date uses Kuwait time, not UTC" do
    # 22:00 UTC on 6 October is already 01:00 on 7 October in Kuwait.
    travel_to Time.utc(2026, 10, 6, 22, 0) do
      assert_nil build_occasion(occurs_on: Date.new(2026, 10, 6)).upcoming_date
      assert_equal Date.new(2026, 10, 7), build_occasion(occurs_on: Date.new(2026, 10, 7)).upcoming_date
    end
  end

  # ---------- Featured ----------

  test "defaults featured to false" do
    assert_not Occasion.new.featured
  end

  test "allows featured to be true or false but not empty" do
    assert build_occasion(featured: true).valid?
    assert_invalid build_occasion(featured: nil), :featured, :inclusion
  end

  test "allows more than one featured occasion" do
    assert occasions(:valentines_day).featured
    assert build_occasion(featured: true).save
  end

  # ---------- Position ----------

  test "defaults position to 0" do
    assert_equal 0, Occasion.new.position
  end

  test "requires position to be a whole number of 0 or more" do
    assert_invalid build_occasion(position: nil), :position, :not_a_number
    assert_invalid build_occasion(position: -1), :position, :greater_than_or_equal_to
    assert_invalid build_occasion(position: 1.5), :position, :not_an_integer
  end

  # ---------- Active ----------

  test "defaults active to true" do
    assert Occasion.new.active
  end

  test "allows active to be true or false but not empty" do
    assert build_occasion(active: false).valid?
    assert_invalid build_occasion(active: nil), :active, :inclusion
  end

  # ---------- Input cleaning ----------

  test "strips spaces from names and taglines" do
    occasion = build_occasion(name_en: "  Eid  ", name_ar: "  عيد  ", tagline_en: "  Celebrate  ", tagline_ar: "  احتفل  ")

    assert_equal "Eid", occasion.name_en
    assert_equal "عيد", occasion.name_ar
    assert_equal "Celebrate", occasion.tagline_en
    assert_equal "احتفل", occasion.tagline_ar
  end

  test "stores blank Arabic name and taglines as nil" do
    occasion = build_occasion(name_ar: "   ", tagline_en: "", tagline_ar: "  ")

    assert_nil occasion.name_ar
    assert_nil occasion.tagline_en
    assert_nil occasion.tagline_ar
  end

  test "strips and lowercases the slug" do
    assert_equal "eid-al-fitr", build_occasion(slug: "  Eid-Al-Fitr  ").slug
  end

  test "still rejects a cleaned slug that has spaces inside" do
    assert_invalid build_occasion(slug: "Eid Al Fitr"), :slug, :invalid
  end

  # ---------- Scopes ----------

  test "active leaves out inactive occasions" do
    assert_includes Occasion.active, occasions(:valentines_day)
    assert_not_includes Occasion.active, occasions(:hidden)
  end

  test "ordered sorts by position" do
    slugs = %w[ hidden-occasion valentines-day birthday graduation ]
    assert_equal slugs, Occasion.ordered.where(slug: slugs).pluck(:slug)
  end

  test "ordered breaks position ties by id" do
    first = Occasion.create!(name_en: "First", slug: "first", position: 5)
    second = Occasion.create!(name_en: "Second", slug: "second", position: 5)

    assert_equal [ first, second ], Occasion.ordered.where(position: 5).to_a
  end

  # ---------- Database rules ----------
  # These skip the model validations to prove the database rejects bad data
  # on its own, for example from the console or bulk inserts.

  test "database rejects a badly formatted slug" do
    assert_raises(ActiveRecord::CheckViolation) do
      build_occasion(slug: "bad slug").save(validate: false)
    end
  end

  test "database rejects a duplicate English name" do
    assert_raises(ActiveRecord::RecordNotUnique) do
      build_occasion(name_en: occasions(:valentines_day).name_en).save(validate: false)
    end
  end

  test "database rejects a duplicate slug" do
    assert_raises(ActiveRecord::RecordNotUnique) do
      build_occasion(slug: occasions(:valentines_day).slug).save(validate: false)
    end
  end

  test "database rejects a missing English name" do
    assert_raises(ActiveRecord::NotNullViolation) do
      build_occasion(name_en: nil).save(validate: false)
    end
  end

  test "database rejects an empty featured flag" do
    assert_raises(ActiveRecord::NotNullViolation) do
      build_occasion(featured: nil).save(validate: false)
    end
  end

  private
    def build_occasion(**attributes)
      Occasion.new({ name_en: "Eid", slug: "eid" }.merge(attributes))
    end

    def assert_invalid(occasion, attribute, error_type)
      assert_not occasion.valid?, "expected #{attribute} #{error_type} error, but the occasion was valid"
      assert occasion.errors.of_kind?(attribute, error_type),
             "expected #{attribute} #{error_type} error, got #{occasion.errors.details[attribute]}"
    end
end
