# Ads the kiosk should rotate right now. The kiosk polls this every few minutes.
class Api::V1::Kiosk::AdsController < Api::V1::Kiosk::BaseController
  def index
    ads = Advertisement.live_for(current_machine).includes(media_attachment: :blob).select { |ad| ad.media.attached? }

    render json: {
      ads: ads.map do |ad|
        {
          id: ad.id,
          title: ad.title,
          type: ad.media_type,
          url: rails_blob_url(ad.media),
          duration_seconds: ad.duration_seconds,
          placements: ad.placements,
          updated_at: ad.updated_at.iso8601
        }
      end
    }
  end
end
