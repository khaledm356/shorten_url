require "rails_helper"

RSpec.describe "ShortUrls", type: :request do
  let(:headers) { { "CONTENT_TYPE" => "application/json" } }
  let(:original_url) { "https://example.com/path" }

  def json_body
    JSON.parse(response.body)
  end

  describe "POST /encode" do
    it "returns shortened URL payload" do
      post "/encode", params: { original_url: original_url }.to_json, headers: headers

      expect(response).to have_http_status(:ok)
      body = json_body
      expect(body["original_url"]).to eq(original_url)
      expect(body["code"]).to be_present
      expect(body["short_url"]).to include(body["code"])
    end

    it "returns 422 for invalid URL" do
      post "/encode", params: { original_url: "ftp://example.com" }.to_json, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "is idempotent for the same URL" do
      post "/encode", params: { original_url: original_url }.to_json, headers: headers
      first_code = json_body["code"]

      post "/encode", params: { original_url: original_url }.to_json, headers: headers
      second_code = json_body["code"]

      expect(second_code).to eq(first_code)
    end
  end

  describe "POST /decode" do
    let(:code) do
      post "/encode", params: { original_url: original_url }.to_json, headers: headers
      json_body["code"]
    end

    it "returns original URL for a code" do
      post "/decode", params: { code: code }.to_json, headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_body["original_url"]).to eq(original_url)
    end

    it "returns original URL for a short URL" do
      post "/decode",
           params: { short_url: "http://short.test/#{code}" }.to_json,
           headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_body["original_url"]).to eq(original_url)
    end

    it "returns 404 for unknown codes" do
      post "/decode", params: { code: "unknown" }.to_json, headers: headers

      expect(response).to have_http_status(:not_found)
      expect(json_body["error"]).to eq("not found")
    end
  end

  describe "GET /:code" do
    it "redirects to the original URL" do
      post "/encode", params: { original_url: original_url }.to_json, headers: headers
      code = json_body["code"]

      get "/#{code}"

      expect(response).to have_http_status(:found)
      expect(response.headers["Location"]).to eq(original_url)
    end
  end
end
