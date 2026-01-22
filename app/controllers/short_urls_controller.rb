require "uri"

class ShortUrlsController < ApplicationController
  rescue_from ActionController::ParameterMissing do |error|
    render json: { error: error.message }, status: :unprocessable_entity
  end

  def encode
    original_url = encode_params[:original_url]
    short_url = ShortUrl.encode!(original_url)

    render json: build_payload(short_url)
  rescue ActiveRecord::RecordInvalid => error
    render json: { error: error.record.errors.full_messages.to_sentence },
           status: :unprocessable_entity
  end

  def decode
    code = decode_code_from_params
    unless code.present?
      render json: { error: "code or short_url is required" }, status: :unprocessable_entity
      return
    end

    short_url = ShortUrl.find_by(code: code)
    if short_url
      render json: { original_url: short_url.original_url }
    else
      render json: { error: "not found" }, status: :not_found
    end
  rescue URI::InvalidURIError
    render json: { error: "short_url is invalid" }, status: :unprocessable_entity
  end

  def redirect
    short_url = ShortUrl.find_by(code: params[:code])
    if short_url
      redirect_to short_url.original_url, status: :found
    else
      render json: { error: "not found" }, status: :not_found
    end
  end

  private

  def encode_params
    params.require(:original_url)
    params.permit(:original_url)
  end

  def decode_code_from_params
    return params[:code] if params[:code].present?
    return if params[:short_url].blank?

    uri = URI.parse(params[:short_url])
    uri.path.to_s.split("/").reject(&:empty?).last
  end

  def base_url
    env_base = ENV["BASE_URL"].to_s.strip
    return env_base.chomp("/") if env_base.present?

    request.base_url
  end

  def build_payload(short_url)
    code = short_url.code
    {
      original_url: short_url.original_url,
      code: code,
      short_url: "#{base_url}/#{code}"
    }
  end
end
