require "test_helper"

class AdvertisementsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in users(:one) }

  test "requires sign in" do
    sign_out :user
    get advertisements_url
    assert_redirected_to new_user_session_path
  end

  test "creates, lists, updates and deletes an ad" do
    get new_advertisement_url
    assert_response :success

    assert_difference -> { Advertisement.count } do
      post advertisements_url, params: { advertisement: {
        title: "Lime soda", duration_seconds: 10, active: "1", position: 2,
        media: fixture_file_upload("test_image.png", "image/png"),
        placements: [ "", "sidebar" ], machine_ids: [ "", machines(:one).id ]
      } }
    end
    assert_redirected_to advertisements_path
    ad = Advertisement.last
    assert_equal %w[sidebar], ad.placements
    assert_equal [ machines(:one) ], ad.machines.to_a

    get advertisements_url
    assert_response :success
    assert_match "Lime soda", response.body

    patch advertisement_url(ad), params: { advertisement: { title: "Lime soda v2", machine_ids: [ "" ] } }
    assert_equal "Lime soda v2", ad.reload.title
    assert_empty ad.machines

    assert_difference -> { Advertisement.count }, -1 do
      delete advertisement_url(ad)
    end
  end

  test "re-renders the form when invalid" do
    post advertisements_url, params: { advertisement: { title: "" } }
    assert_response :unprocessable_entity
  end
end
