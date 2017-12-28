require "net/http"
require "openssl"

class ModuleInstance
  class << self
    attr_accessor :errors
    include BranchIOCLI::Helper::IOSHelper
  end
end

describe BranchIOCLI::Helper::IOSHelper do
  let (:instance) { ModuleInstance }

  before :each do
    instance.errors = []
    instance.reset_aasa_cache
  end

  describe "constants" do
    it "defines APPLINKS" do
      expect(BranchIOCLI::Helper::IOSHelper::APPLINKS).to eq "applinks"
    end

    it "defines ASSOCIATED_DOMAINS" do
      expect(BranchIOCLI::Helper::IOSHelper::ASSOCIATED_DOMAINS).to eq "com.apple.developer.associated-domains"
    end

    it "defines CODE_SIGN_ENTITLEMENTS" do
      expect(BranchIOCLI::Helper::IOSHelper::CODE_SIGN_ENTITLEMENTS).to eq "CODE_SIGN_ENTITLEMENTS"
    end

    it "defines DEVELOPMENT_TEAM" do
      expect(BranchIOCLI::Helper::IOSHelper::DEVELOPMENT_TEAM).to eq "DEVELOPMENT_TEAM"
    end

    it "defines PRODUCT_BUNDLE_IDENTIFIER" do
      expect(BranchIOCLI::Helper::IOSHelper::PRODUCT_BUNDLE_IDENTIFIER).to eq "PRODUCT_BUNDLE_IDENTIFIER"
    end

    it "defines RELEASE_CONFIGURATION" do
      expect(BranchIOCLI::Helper::IOSHelper::RELEASE_CONFIGURATION).to eq "Release"
    end
  end

  describe "#app_ids_from_aasa_file" do
    it "parses the contents of an apple-app-site-assocation file" do
      mock_response = '{"applinks":{"apps":[],"details":[{"appID":"XYZPDQ.com.example.MyApp","paths":["NOT /e/*","*","/"]}]}}'

      expect(instance).to receive(:contents_of_aasa_file).with("myapp.app.link") { mock_response }

      expect(instance.app_ids_from_aasa_file("myapp.app.link")).to eq %w{XYZPDQ.com.example.MyApp}
      expect(instance.errors).to be_empty
    end

    it "raises if the file cannot be retrieved" do
      expect(instance).to receive(:contents_of_aasa_file).and_raise RuntimeError

      expect do
        instance.app_ids_from_aasa_file("myapp.app.link")
      end.to raise_error RuntimeError
    end

    it "returns nil in case of unparseable JSON" do
      # return value missing final }
      mock_response = '{"applinks":{"apps":[],"details":[{"appID":"XYZPDQ.com.example.MyApp","paths":["NOT /e/*","*","/"]}]}'
      expect(instance).to receive(:contents_of_aasa_file).with("myapp.app.link") { mock_response }

      expect(instance.app_ids_from_aasa_file("myapp.app.link")).to be_nil
      expect(instance.errors).not_to be_empty
    end

    it "returns nil if no applinks found in file" do
      mock_response = '{"webcredentials": {}}'
      expect(instance).to receive(:contents_of_aasa_file).with("myapp.app.link") { mock_response }

      expect(instance.app_ids_from_aasa_file("myapp.app.link")).to be_nil
      expect(instance.errors).not_to be_empty
    end

    it "returns nil if no details found for applinks" do
      mock_response = '{"applinks": {}}'
      expect(instance).to receive(:contents_of_aasa_file).with("myapp.app.link") { mock_response }

      expect(instance.app_ids_from_aasa_file("myapp.app.link")).to be_nil
      expect(instance.errors).not_to be_empty
    end

    it "returns nil if no appIDs found in file" do
      mock_response = '{"applinks":{"apps":[],"details":[]}}'
      expect(instance).to receive(:contents_of_aasa_file).with("myapp.app.link") { mock_response }

      expect(instance.app_ids_from_aasa_file("myapp.app.link")).to be_nil
      expect(instance.errors).not_to be_empty
    end
  end

  describe "#contents_of_aasa_file" do
    it "returns the contents of an unsigned AASA file" do
      mock_contents = "{}"
      mock_response = double "response", body: mock_contents, code: "200", message: "OK"
      expect(mock_response).to receive(:[]).with("Content-type") { "application/json" }

      mock_http_request mock_response

      expect(instance.contents_of_aasa_file("myapp.app.link")).to eq mock_contents
    end

    it "returns the contents of a signed AASA file" do
      mock_contents = "{}"
      mock_response = double "response", code: "200", message: "OK", body: ""
      expect(mock_response).to receive(:[]).with("Content-type") { "application/pkcs7-mime" }

      mock_signature = double "signature", data: mock_contents
      # just ensure verify doesn't raise
      expect(mock_signature).to receive(:verify)
      # and return the mock_contents as signature.data
      expect(OpenSSL::PKCS7).to receive(:new) { mock_signature }

      mock_http_request mock_response

      expect(instance.contents_of_aasa_file("myapp.app.link")).to eq mock_contents
    end

    it "returns nil if the file cannot be retrieved" do
      mock_response = double "response", code: "404", message: "Not Found"

      mock_http_request mock_response

      expect(instance.contents_of_aasa_file("myapp.app.link")).to be_nil
      expect(instance.errors).not_to be_empty
    end

    it "returns nil if the response does not contain a Content-type" do
      mock_contents = "{}"
      mock_response = double "response", body: mock_contents, code: "200", message: "OK"
      expect(mock_response).to receive(:[]).at_least(:once).with("Content-type") { nil }

      mock_http_request mock_response

      expect(instance.contents_of_aasa_file("myapp.app.link")).to be_nil
      expect(instance.errors).not_to be_empty
    end

    it "returns nil in case of a redirect" do
      mock_response = double "response", code: "302", message: "Moved Permanently"

      mock_http_request mock_response

      expect(STDOUT).to receive(:puts).with(/redirect/i).at_least(:once)
      expect(instance.contents_of_aasa_file("myapp.app.link")).to be_nil
      expect(instance.errors).not_to be_empty
    end
  end

  describe '#validate_team_and_bundle_ids_from_aasa_files' do
    it 'only succeeds if all domains are valid' do
      # No domains in project. Just validating what's passed in.
      expect(instance).to receive(:domains_from_project) { [] }
      # example.com is valid
      expect(instance).to receive(:validate_team_and_bundle_ids)
        .with("example.com", "Release") { true }
      # www.example.com is not valid
      expect(instance).to receive(:validate_team_and_bundle_ids)
        .with("www.example.com", "Release") { false }

      valid = instance.validate_team_and_bundle_ids_from_aasa_files(
        %w{example.com www.example.com}
      )
      expect(valid).to be false
    end

    it 'succeeds if all domains are valid' do
      # No domains in project. Just validating what's passed in.
      expect(instance).to receive(:domains_from_project) { [] }
      # example.com is valid
      expect(instance).to receive(:validate_team_and_bundle_ids)
        .with("example.com", "Release") { true }
      # www.example.com is not valid
      expect(instance).to receive(:validate_team_and_bundle_ids)
        .with("www.example.com", "Release") { true }

      valid = instance.validate_team_and_bundle_ids_from_aasa_files(
        %w{example.com www.example.com}
      )
      expect(valid).to be true
    end

    it 'fails if no domains specified and no domains in project' do
      # No domains in project. Just validating what's passed in.
      expect(instance).to receive(:domains_from_project) { [] }

      valid = instance.validate_team_and_bundle_ids_from_aasa_files(
        []
      )
      expect(valid).to be false
    end
  end

  def mock_http_request(mock_response)
    mock_http = double "http", peer_cert: nil
    expect(mock_http).to receive(:request).at_least(:once) { mock_response }
    expect(Net::HTTP).to receive(:start).at_least(:once).and_yield mock_http
  end
end
