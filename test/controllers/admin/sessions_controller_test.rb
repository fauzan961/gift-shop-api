require "test_helper"

class Admin::SessionsControllerTest < ActionDispatch::IntegrationTest
  PASSWORD = "long enough password"

  setup do
    Admin::SessionsController.cache_store.clear
    @admin_user = AdminUser.create!(name: "Fauzan", email: "fauzan@giftie.com", password: PASSWORD)
  end

  # ---------- Sign-in page ----------

  test "shows the sign-in page" do
    get new_admin_session_path

    assert_response :success
    assert_select "title", "Admin sign in"
    assert_select "form[action=?][method=post]", admin_session_path
    assert_select "input[type=email][name=email]"
    assert_select "input[type=password][name=password]"
  end

  # ---------- Signing in ----------

  test "signs in with the right email and password" do
    sign_in

    assert_redirected_to admin_root_path
    assert_equal @admin_user.id, session[:admin_user_id]
  end

  test "signs in with the email in any letter case and with spaces" do
    sign_in email: "  FAUZAN@Giftie.com "

    assert_redirected_to admin_root_path
  end

  test "starts a new session on sign-in" do
    delete admin_session_path
    old_session_id = session.id.to_s
    assert_not_empty old_session_id

    sign_in

    assert_not_equal old_session_id, session.id.to_s
  end

  test "refuses a wrong password, an unknown email or a blocked admin with the same message" do
    blocked = AdminUser.create!(name: "Sara", email: "sara@giftie.com", password: PASSWORD, active: false)

    [ { email: @admin_user.email, password: "wrong password" }, { email: "nobody@giftie.com", password: PASSWORD },
      { email: blocked.email, password: PASSWORD }, {} ].each do |credentials|
      post admin_session_path, params: credentials

      assert_response :unprocessable_content, credentials.inspect
      assert_select ".alert", "Email or password is incorrect."
      assert_nil session[:admin_user_id]
    end
  end

  test "keeps the email filled in after a failed attempt" do
    post admin_session_path, params: { email: @admin_user.email, password: "wrong password" }

    assert_select "input[name=email][value=?]", @admin_user.email
    assert_select "input[name=password][value]", false
  end

  test "limits sign-in attempts from one IP address" do
    10.times { post admin_session_path, params: { email: @admin_user.email, password: "wrong password" } }

    sign_in

    assert_redirected_to new_admin_session_path
    assert_equal "Too many sign-in attempts. Try again in a few minutes.", flash[:alert]
    assert_nil session[:admin_user_id]
  end

  # ---------- Signing out ----------

  test "signs out and clears the session" do
    sign_in

    delete admin_session_path

    assert_redirected_to new_admin_session_path
    assert_nil session[:admin_user_id]
    follow_redirect!
    assert_select ".notice", "You have been signed out."
  end

  # ---------- Admin pages ----------

  test "admin pages send a visitor who is not signed in to the sign-in page" do
    [ admin_root_path, admin_categories_path, new_admin_category_path, edit_admin_category_path(categories(:flowers)) ].each do |path|
      get path

      assert_redirected_to new_admin_session_path, path
    end
  end

  test "admin pages cannot change data without signing in" do
    post admin_categories_path, params: { category: { name_en: "Balloons", slug: "balloons" } }
    delete admin_category_path(categories(:hidden))

    assert_not Category.exists?(slug: "balloons")
    assert Category.exists?(categories(:hidden).id)
  end

  test "admin pages ignore a customer's token" do
    get admin_categories_path, headers: { "Authorization" => "Bearer layla-phone-token" }

    assert_redirected_to new_admin_session_path
  end

  test "admin pages open once signed in" do
    sign_in

    get admin_categories_path

    assert_response :success
  end

  test "blocking an admin signs them out on their next page" do
    sign_in
    @admin_user.update!(active: false)

    get admin_categories_path

    assert_redirected_to new_admin_session_path
  end

  private
    def sign_in(email: @admin_user.email, password: PASSWORD)
      post admin_session_path, params: { email: email, password: password }
    end
end
