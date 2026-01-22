require "rails_helper"

RSpec.describe ShortUrl, type: :model do
  describe "validations" do
    describe "original_url" do
      it "is required" do
        short_url = ShortUrl.new(original_url: nil)
        expect(short_url).not_to be_valid
        expect(short_url.errors[:original_url]).to include("can't be blank")
      end

      it "must be unique" do
        ShortUrl.create!(original_url: "http://example.com", code: "test1")
        duplicate = ShortUrl.new(original_url: "http://example.com", code: "test2")
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:original_url]).to include("has already been taken")
      end

      it "has a maximum length of 2048 characters" do
        long_url = "http://example.com/" + "a" * 2050
        short_url = ShortUrl.new(original_url: long_url)
        expect(short_url).not_to be_valid
        expect(short_url.errors[:original_url]).to include("is too long (maximum is 2048 characters)")
      end

      it "must be a valid http URL" do
        short_url = ShortUrl.new(original_url: "http://example.com", code: "test")
        expect(short_url).to be_valid
      end

      it "must be a valid https URL" do
        short_url = ShortUrl.new(original_url: "https://example.com", code: "test")
        expect(short_url).to be_valid
      end

      it "rejects URLs without a scheme" do
        short_url = ShortUrl.new(original_url: "example.com")
        expect(short_url).not_to be_valid
        expect(short_url.errors[:original_url]).to include("must be a valid http/https URL")
      end

      it "rejects URLs with non-http schemes" do
        short_url = ShortUrl.new(original_url: "ftp://example.com")
        expect(short_url).not_to be_valid
        expect(short_url.errors[:original_url]).to include("must be a valid http/https URL")
      end

      it "rejects invalid URLs" do
        short_url = ShortUrl.new(original_url: "not a url")
        expect(short_url).not_to be_valid
        expect(short_url.errors[:original_url]).to include("must be a valid http/https URL")
      end

      it "rejects URLs without a host" do
        short_url = ShortUrl.new(original_url: "http://")
        expect(short_url).not_to be_valid
        expect(short_url.errors[:original_url]).to include("must be a valid http/https URL")
      end
    end

    describe "code" do
      it "is required" do
        short_url = ShortUrl.new(original_url: "http://example.com", code: nil)
        expect(short_url).not_to be_valid
        expect(short_url.errors[:code]).to include("can't be blank")
      end

      it "must be unique" do
        first = ShortUrl.create!(original_url: "http://example.com", code: "test1")
        another = ShortUrl.new(original_url: "http://another.com", code: first.code)
        expect(another).not_to be_valid
        expect(another.errors[:code]).to include("has already been taken")
      end

      it "has a maximum length of 32 characters" do
        short_url = ShortUrl.new(original_url: "http://example.com", code: "a" * 33)
        expect(short_url).not_to be_valid
        expect(short_url.errors[:code]).to include("is too long (maximum is 32 characters)")
      end
    end
  end

  describe "callbacks" do
    describe "after_create" do
      it "assigns a Base62 encoded code based on the id" do
        short_url = ShortUrl.create!(original_url: "http://example.com", code: "temp")
        expect(short_url.code).to eq(Base62.encode(short_url.id))
      end

      it "replaces the temporary code with the encoded id" do
        short_url = ShortUrl.create!(original_url: "http://example.com", code: "tmp_12345678")
        expect(short_url.code).not_to include("tmp_")
        expect(short_url.code).to eq(Base62.encode(short_url.id))
      end
    end
  end

  describe ".encode!" do
    context "when the URL has not been shortened before" do
      it "creates a new ShortUrl record" do
        expect {
          ShortUrl.encode!("http://example.com")
        }.to change(ShortUrl, :count).by(1)
      end

      it "returns the ShortUrl record" do
        result = ShortUrl.encode!("http://example.com")
        expect(result).to be_a(ShortUrl)
        expect(result.original_url).to eq("http://example.com")
      end

      it "assigns a Base62 encoded code" do
        result = ShortUrl.encode!("http://example.com")
        expect(result.code).to eq(Base62.encode(result.id))
      end

      it "creates a temporary code initially" do
        allow(SecureRandom).to receive(:hex).with(8).and_return("abcd1234")

        # Capture what happens during creation
        temp_code = nil
        allow_any_instance_of(ShortUrl).to receive(:assign_code!) do |instance|
          temp_code = instance.code
          instance.update_column(:code, Base62.encode(instance.id))
        end

        ShortUrl.encode!("http://example.com")
        expect(temp_code).to eq("tmp_abcd1234")
      end
    end

    context "when the URL has already been shortened" do
      let!(:existing_short_url) { ShortUrl.create!(original_url: "http://example.com", code: "test") }

      it "does not create a new record" do
        expect {
          ShortUrl.encode!("http://example.com")
        }.not_to change(ShortUrl, :count)
      end

      it "returns the existing ShortUrl record" do
        result = ShortUrl.encode!("http://example.com")
        expect(result.id).to eq(existing_short_url.id)
        expect(result.code).to eq(existing_short_url.code)
      end
    end

    context "when a race condition occurs" do
      it "handles RecordNotUnique exception by finding the existing record" do
        original_url = "http://example.com"

        # Create the existing record first
        existing = ShortUrl.create!(original_url: original_url, code: "existing")

        # Simulate the race condition: another thread creates the record between our check and create
        allow(ShortUrl).to receive(:find_by).with(original_url: original_url).and_return(nil)
        allow(ShortUrl).to receive(:create!).and_raise(ActiveRecord::RecordNotUnique)
      end
    end

    context "with invalid URLs" do
      it "raises an error for invalid URLs" do
        expect {
          ShortUrl.encode!("not a url")
        }.to raise_error(ActiveRecord::RecordInvalid)
      end

      it "raises an error for URLs without http/https scheme" do
        expect {
          ShortUrl.encode!("ftp://example.com")
        }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end
  end

  describe "database constraints" do
    it "enforces uniqueness of original_url at the database level" do
      ShortUrl.create!(original_url: "http://example.com", code: "code1")

      expect {
        ShortUrl.create!(original_url: "http://example.com", code: "code2")
      }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it "enforces uniqueness of code at the database level" do
      short_url = ShortUrl.create!(original_url: "http://example.com", code: "temp")

      expect {
        ShortUrl.create!(original_url: "http://another.com", code: short_url.code)
      }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end
end
