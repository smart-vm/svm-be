require "test_helper"

class AdvertisementTest < ActiveSupport::TestCase
  def build_ad(**attrs)
    ad = Advertisement.new({ title: "Lime soda", duration_seconds: 8 }.merge(attrs))
    ad.media.attach(io: StringIO.new("png"), filename: "ad.png", content_type: "image/png")
    ad
  end

  test "defaults to every placement and needs media" do
    ad = build_ad
    assert ad.valid?
    assert_equal Advertisement::PLACEMENTS.keys, ad.placements

    no_media = Advertisement.new(title: "x")
    assert_not no_media.valid?
    assert_includes no_media.errors[:media], "must be an image or video"
  end

  test "rejects unknown placements, bad durations, odd files and inverted schedules" do
    assert_not build_ad(placements: [ "payment" ]).valid?
    assert_not build_ad(duration_seconds: 1).valid?
    assert_not build_ad(starts_at: 1.day.from_now, ends_at: Time.current).valid?

    gif = Advertisement.new(title: "gif")
    gif.media.attach(io: StringIO.new("gif"), filename: "a.gif", content_type: "image/gif")
    assert_not gif.valid?
  end

  test "live_for respects active flag, schedule and machine targeting" do
    everywhere = build_ad(title: "everywhere").tap(&:save!)
    targeted = build_ad(title: "machine two only").tap { |a| a.machines << machines(:two) }.tap(&:save!)
    build_ad(title: "paused", active: false).save!
    build_ad(title: "future", starts_at: 1.day.from_now).save!
    build_ad(title: "over", starts_at: 2.days.ago, ends_at: 1.day.ago).save!

    assert_equal [ everywhere ], Advertisement.live_for(machines(:one)).to_a
    assert_equal [ everywhere, targeted ].sort_by(&:id), Advertisement.live_for(machines(:two)).to_a.sort_by(&:id)
    assert_equal "scheduled", Advertisement.find_by(title: "future").schedule_status
    assert_equal "ended", Advertisement.find_by(title: "over").schedule_status
  end
end
