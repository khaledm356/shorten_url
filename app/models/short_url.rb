require "securerandom"
require "uri"

class ShortUrl < ApplicationRecord
  validates :original_url, presence: true, length: { maximum: 2048 }, uniqueness: true
  validates :code, presence: true, length: { maximum: 32 }, uniqueness: true
  validate :original_url_format

  after_create :assign_code!

  def self.encode!(original_url)
    record = find_by(original_url: original_url)
    return record if record

    create!(original_url: original_url, code: "tmp_#{SecureRandom.hex(8)}").tap do |short_url|
      short_url.reload
    end
  rescue ActiveRecord::RecordNotUnique
    find_by!(original_url: original_url)
  end

  private

  def assign_code!
    update_column(:code, Base62.encode(id))
  end

  def original_url_format
    return if original_url.blank?

    uri = URI.parse(original_url)
    return if uri.is_a?(URI::HTTP) && uri.host.present?

    errors.add(:original_url, 'must be a valid http/https URL')
  rescue URI::InvalidURIError
    errors.add(:original_url, 'must be a valid http/https URL')
  end
end
