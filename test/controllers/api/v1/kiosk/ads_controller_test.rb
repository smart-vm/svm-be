require "test_helper"

class Api::V1::Kiosk::AdsControllerTest < ActionDispatch::IntegrationTest
  test "returns the live ads for the calling machine" do
    ad = Advertisement.new(title: "Lime soda", duration_seconds: 6, placements: %w[sidebar attract])
    ad.media.attach(io: StringIO.new("png"), filename: "ad.png", content_type: "image/png")
    ad.save!

    get api_v1_kiosk_ads_url, headers: kiosk_headers, as: :json

    assert_response :success
    item = response.parsed_body["ads"].sole
    assert_equal({ "id" => ad.id, "type" => "image", "duration_seconds" => 6, "placements" => %w[sidebar attract] },
                 item.slice("id", "type", "duration_seconds", "placements"))
    assert_match %r{/rails/active_storage/blobs/}, item["url"]
  end

  test "requires the machine token" do
    get api_v1_kiosk_ads_url, as: :json
    assert_response :unauthorized
  end
end
