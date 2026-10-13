namespace :svm do
  SAMPLE_ADS = [
    { title: "Fresh Lime Soda (sample)", file: "fresh-lime-soda.png", position: 1 },
    { title: "Kafe Sebelah — Kopi Pagi (sample)", file: "kopi-pagi.png", position: 2 },
    { title: "SmartVend — Bayar pakai QRIS (sample)", file: "smartvend-qris.png", position: 3 }
  ].freeze

  desc "Add three sample (non-tobacco) ads so the kiosk ad space has content"
  task sample_ads: :environment do
    SAMPLE_ADS.each do |attrs|
      ad = Advertisement.find_or_initialize_by(title: attrs[:title])
      unless ad.media.attached?
        file = Rails.root.join("db/seeds/images/ads", attrs[:file])
        ad.media.attach(io: File.open(file), filename: attrs[:file], content_type: "image/png")
      end
      ad.update!(position: attrs[:position], duration_seconds: 8, active: true)
      puts "#{ad.title}: #{ad.schedule_status}"
    end
  end
end
