class Advertisement < ApplicationRecord
  # Kiosk screens an ad can appear on. Payment screens never show ads.
  PLACEMENTS = {
    "sidebar" => "Product screen (side column, portrait)",
    "attract" => "Idle screen (full screen, landscape)",
    "dispensing" => "While dispensing (16:9)"
  }.freeze
  IMAGE_TYPES = %w[image/png image/jpeg image/webp].freeze
  VIDEO_TYPES = %w[video/mp4].freeze
  MAX_BYTES = 50.megabytes

  has_one_attached :media
  has_many :advertisement_machines, dependent: :destroy
  has_many :machines, through: :advertisement_machines

  before_validation :default_placements

  validates :title, presence: true
  validates :duration_seconds, numericality: { only_integer: true, in: 3..60 }
  validate :media_must_be_valid
  validate :placements_must_be_known
  validate :ends_after_start

  # Active, inside its schedule, and either untargeted or targeted at machine.
  def self.live_for(machine, at: Time.current)
    where(active: true)
      .where("starts_at IS NULL OR starts_at <= ?", at)
      .where("ends_at IS NULL OR ends_at >= ?", at)
      .where(<<~SQL, machine.id)
        NOT EXISTS (SELECT 1 FROM advertisement_machines am WHERE am.advertisement_id = advertisements.id)
        OR EXISTS (SELECT 1 FROM advertisement_machines am WHERE am.advertisement_id = advertisements.id AND am.machine_id = ?)
      SQL
      .order(:position, :id)
  end

  def video?
    media.attached? && VIDEO_TYPES.include?(media.content_type)
  end

  def media_type
    video? ? "video" : "image"
  end

  def schedule_status(at = Time.current)
    return "paused" unless active?
    return "scheduled" if starts_at && starts_at > at
    return "ended" if ends_at && ends_at < at

    "live"
  end

  private

  def default_placements
    self.placements = Array(placements).compact_blank
    self.placements = PLACEMENTS.keys if placements.empty?
  end

  def media_must_be_valid
    unless media.attached?
      errors.add(:media, "must be an image or video")
      return
    end
    unless (IMAGE_TYPES + VIDEO_TYPES).include?(media.content_type)
      errors.add(:media, "must be PNG, JPG, WebP or MP4")
    end
    errors.add(:media, "must be 50 MB or smaller") if media.byte_size.to_i > MAX_BYTES
  end

  def placements_must_be_known
    unknown = placements - PLACEMENTS.keys
    errors.add(:placements, "contains unknown screens: #{unknown.join(', ')}") if unknown.any?
  end

  def ends_after_start
    errors.add(:ends_at, "must be after the start") if starts_at && ends_at && ends_at <= starts_at
  end
end
