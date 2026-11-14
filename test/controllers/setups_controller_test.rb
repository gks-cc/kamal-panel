require "test_helper"

class SetupsControllerTest < ActionDispatch::IntegrationTest
  setup do
    User.delete_all
    Rails.cache.clear
  end

  def admin_params = { user: { email_address: "boss@example.com", password: "s3cret-pass", password_confirmation: "s3cret-pass" } }

  test "a fresh panel sends the login page to setup" do
    get new_session_path

    assert_redirected_to setup_path
  end

  test "without the token, setup says where the link is and never shows it" do
    get setup_path

    assert_response :ok
    assert_select "form", count: 0
    assert_no_match FirstRunSetup.token, response.body
  end

  test "with the token, creates the admin, signs them in and retires the token" do
    token = FirstRunSetup.token
    get setup_path(token:)
    assert_select "form"

    post setup_path, params: admin_params.merge(token:)

    assert_redirected_to root_path
    user = User.sole
    assert user.admin?
    assert_equal "user.create", AuditLog.last.action_name
    assert_not_equal token, FirstRunSetup.token
  end

  test "a wrong token creates nobody" do
    FirstRunSetup.token
    post setup_path, params: admin_params.merge(token: "guess")

    assert_equal 0, User.count
  end

  test "shows validation errors without creating the admin" do
    post setup_path, params: admin_params.deep_merge(token: FirstRunSetup.token, user: { password_confirmation: "different" })

    assert_response :unprocessable_entity
    assert_equal 0, User.count
  end

  test "is gone once any user exists" do
    token = FirstRunSetup.token
    User.create!(email_address: "first@example.com", password: "s3cret-pass", role: "admin")

    get setup_path(token:)
    assert_redirected_to new_session_path

    post setup_path, params: admin_params.merge(token:)
    assert_equal 1, User.count
  end
end
