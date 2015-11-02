require 'rack/test'
require_relative '../../spec_helper'

include Rack::Test::Methods

def app
  Sinatra::Application
end

describe Postoffice::AppService do

  before do
    @person1 = create(:person, username: random_username)
    @person2 = create(:person, username: random_username)
    @person3 = create(:person, username: random_username)

    @mail1 = create(:mail, correspondents: [build(:from_person, person_id: @person1.id), build(:to_person, person_id: @person2.id)])
    @mail2 = create(:mail, correspondents: [build(:from_person, person_id: @person3.id), build(:to_person, person_id: @person1.id)])

    @admin_token = Postoffice::AuthService.get_admin_token
    @app_token = Postoffice::AuthService.get_app_token
    @person1_token = Postoffice::AuthService.generate_token_for_person @person1
    @person2_token = Postoffice::AuthService.generate_token_for_person @person2
  end

  describe 'get token from authorization header' do

    it 'must return the token if one is provided' do
      get "/", nil, {"HTTP_AUTHORIZATION" => "Bearer #{@admin_token}"}
      Postoffice::AppService.get_token_from_authorization_header(last_request).must_equal @admin_token
    end

    it 'must return nil if no token was provided' do
      get "/"
      Postoffice::AppService.get_token_from_authorization_header(last_request).must_equal nil
    end

  end

  describe 'get payload from request bearer' do

    describe 'get a valid token' do

      before do
        get "/", nil, {"HTTP_AUTHORIZATION" => "Bearer #{@admin_token}"}
        @payload = Postoffice::AppService.get_payload_from_authorization_header last_request
      end

      it 'must get return the payload of the auth token included in the header as a hash' do
        @payload.must_be_instance_of Hash
      end

      it 'must include the scope in the payload' do
        @payload["scope"].must_equal Postoffice::AuthService.get_scopes_for_user_type "admin"
      end

    end

    describe 'invalid tokens' do

      it 'must return a message if the token has expired' do
        expiring_payload = { :data => "test", :exp => Time.now.to_i - 60 }
        expiring_token = Postoffice::AuthService.generate_token expiring_payload
        get "/", nil, {"HTTP_AUTHORIZATION" => "Bearer #{expiring_token}"}

        Postoffice::AppService.get_payload_from_authorization_header(last_request).must_equal "Token expired"
      end

      it 'must return an error message if the token is invalid' do
        invalid_token = "abc.123.def"
        get "/", nil, {"HTTP_AUTHORIZATION" => "Bearer #{invalid_token}"}

        Postoffice::AppService.get_payload_from_authorization_header(last_request).must_equal "Token is invalid"
      end

      it 'must raise an error message if the token is not signed by the correct certificate' do
        rsa_private = OpenSSL::PKey::RSA.generate 2048
        payload = { :data => "test" }
        token = JWT.encode payload, rsa_private, 'RS256'
        get "/", nil, {"HTTP_AUTHORIZATION" => "Bearer #{token}"}

        Postoffice::AppService.get_payload_from_authorization_header(last_request).must_equal "Invalid token signature"
      end

      it 'must return an error message if the Authorization header is not provided' do
        get "/"
        Postoffice::AppService.get_payload_from_authorization_header(last_request).must_equal "No token provided"
      end

    end

  end

  describe 'check authorization' do

    it 'must return false if the request Authorization includes the required scope' do
      get "/", nil, {"HTTP_AUTHORIZATION" => "Bearer #{@admin_token}"}
      Postoffice::AppService.unauthorized?(last_request, "admin").must_equal false
    end

    it 'must return true if the request Authorization does not include the required scope' do
      get "/", nil, {"HTTP_AUTHORIZATION" => "Bearer #{@app_token}"}
      Postoffice::AppService.unauthorized?(last_request, "admin").must_equal true
    end

    it 'must return true if no Authorization header is submitted' do
      get "/"
      Postoffice::AppService.unauthorized?(last_request, "admin").must_equal true
    end

    it 'must return true is the token has been marked as invalid in the database' do
      token = Postoffice::AuthService.get_test_token
      db_token = Postoffice::Token.create(value: token, is_invalid: true)
      db_token.save
      get "/", nil, {"HTTP_AUTHORIZATION" => "Bearer #{token}"}
      Postoffice::AppService.unauthorized?(last_request, "admin").must_equal true
    end

  end

  describe 'check authorized ownership' do

    it 'must return true if the token has been marked as invalid' do
      db_token = Postoffice::Token.create(value: @person1_token, is_invalid: true)
      get "/", nil, {"HTTP_AUTHORIZATION" => "Bearer #{@person1_token}"}
      Postoffice::AppService.not_authorized_owner?(last_request, "can-read", @person1.id.to_s).must_equal true
    end

    it 'must return false if the person_id is in the payload and it has the required scope' do
      get "/", nil, {"HTTP_AUTHORIZATION" => "Bearer #{@person1_token}"}
      Postoffice::AppService.not_authorized_owner?(last_request, "can-read", @person1.id.to_s).must_equal false
    end

    it 'must return true if the person_id is in the payload but it does not have the required scope' do
      get "/", nil, {"HTTP_AUTHORIZATION" => "Bearer #{@person1_token}"}
      Postoffice::AppService.not_authorized_owner?(last_request, "create-person", @person1.id.to_s).must_equal true
    end

    it 'must return true if the person_id is not in the payload' do
      get "/", nil, {"HTTP_AUTHORIZATION" => "Bearer #{@person1_token}"}
      Postoffice::AppService.not_authorized_owner?(last_request, "can-read", @person2.id.to_s).must_equal true
    end

  end

  describe 'check admin or ownership' do

    it 'must return false if the token has the admin scope' do
      get "/", nil, {"HTTP_AUTHORIZATION" => "Bearer #{@admin_token}"}
      Postoffice::AppService.not_admin_or_owner?(last_request, "can-read", @person1.id.to_s).must_equal false
    end

    it 'must return false if the person_id is in the token and the scope is correct' do
      get "/", nil, {"HTTP_AUTHORIZATION" => "Bearer #{@person1_token}"}
      Postoffice::AppService.not_admin_or_owner?(last_request, "can-read", @person1.id.to_s).must_equal false
    end

    it 'must return true if the token does not include the required scope and is not admin' do
      get "/", nil, {"HTTP_AUTHORIZATION" => "Bearer #{@person1_token}"}
      Postoffice::AppService.not_admin_or_owner?(last_request, "reset-password", @person1.id.to_s).must_equal true
    end

    it 'must return true if it is the wrong person' do
      get "/", nil, {"HTTP_AUTHORIZATION" => "Bearer #{@person1_token}"}
      Postoffice::AppService.not_admin_or_owner?(last_request, "can-read", @person2.id.to_s).must_equal true
    end

  end

  describe 'check admin or mail ownership' do

    it 'must return false if the token has the admin scope' do
      get "/", nil, {"HTTP_AUTHORIZATION" => "Bearer #{@admin_token}"}
      Postoffice::AppService.not_admin_or_mail_owner?(last_request, "can-read", @mail1).must_equal false
    end

    it 'must return false if the mail is from the person and they have the required scope' do
      get "/", nil, {"HTTP_AUTHORIZATION" => "Bearer #{@person1_token}"}
      Postoffice::AppService.not_admin_or_mail_owner?(last_request, "can-read", @mail1).must_equal false
    end

    it 'must return false if the mail is to the person and they have the required scope' do
      get "/", nil, {"HTTP_AUTHORIZATION" => "Bearer #{@person2_token}"}
      Postoffice::AppService.not_admin_or_mail_owner?(last_request, "can-read", @mail1).must_equal false
    end

    it 'must return true if the token does not include the required scope and is not admin' do
      get "/", nil, {"HTTP_AUTHORIZATION" => "Bearer #{@person1_token}"}
      Postoffice::AppService.not_admin_or_mail_owner?(last_request, "reset-password", @mail1).must_equal true
    end

    it 'must return true if it is the wrong person' do
      get "/", nil, {"HTTP_AUTHORIZATION" => "Bearer #{@person2_token}"}
      Postoffice::AppService.not_admin_or_mail_owner?(last_request, "can-read", @mail2).must_equal true
    end

  end

  describe 'get API version from content-type header' do

    it 'must parse the version from the CONTENT_TYPE header if the header begins with application/vnd.postoffice' do
        get "/", nil, {"HTTP_AUTHORIZATION" => "Bearer #{@admin_token}", "CONTENT_TYPE" => "application/vnd.postoffice.v2+json"}
        Postoffice::AppService.get_api_version_from_content_type(last_request).must_equal "v2"
    end

    it 'must return V1 if the version is not included in the CONTENT_TYPE header' do
      get "/", nil, {"HTTP_AUTHORIZATION" => "Bearer #{@admin_token}"}
      Postoffice::AppService.get_api_version_from_content_type(last_request).must_equal "v1"
    end

  end

  describe 'add updated since to query' do

    before do
      @query = Postoffice::Mail.where(status: "DELIVERED")
    end

    describe 'params include updated_at' do

      before do
        @params = Hash(updated_at: { "$gt" => (Time.now + 4.minutes) })
        @query = Postoffice::AppService.add_updated_since_to_query @query, @params
      end

      it 'must have added updated_at to the query' do
        @query.selector["updated_at"].must_equal @params[:updated_at]
      end

      it 'must have preserved the original parts of the query' do
        @query.selector.keys.must_equal ["status", "updated_at"]
      end

    end

    describe 'params do not include updated_at' do

      before do
        params = Hash.new
        @query = Postoffice::AppService.add_updated_since_to_query @query, params
      end

      it 'must not have added updated_at to the query' do
        @query.selector.keys.include?("updated_at").must_equal false
      end

    end

  end

  describe 'convert objects to documents' do

    before do
      array = [@person1, @person2, @person3]
      @documents = Postoffice::AppService.convert_objects_to_documents array
    end

    it 'must return Hash documents' do
      @documents[0].must_be_instance_of Hash
    end

    it 'must convert the objects to these documents' do
      @documents[0].must_equal @person1.as_document
    end

    it 'must return all of the documents' do
      @documents.count.must_equal 3
    end

  end

  describe 'create json of mail for person' do

    before do
      @mail_array = [@mail1]
      @json = Postoffice::AppService.create_json_of_mail_for_person @mail_array, @person2
    end

    it 'must return a string' do
      @json.must_be_instance_of String
    end

    it 'must return an array' do
      JSON.parse(@json).must_be_instance_of Array
    end

    it 'must contain the custom hash for a mail to be shown to a person' do
      expected_result = JSON.parse(Postoffice::MailService.hash_of_mail_for_person(@mail1, @person2).to_json)
      JSON.parse(@json)[0].must_equal expected_result
    end

  end

  describe 'email api key' do

    it 'must return the test key for test requests' do
      get '/?test=true'
      Postoffice::AppService.email_api_key(last_request).must_equal "POSTMARK_API_TEST"
    end

    it 'must return the api key for real requests' do
      get '/'
      Postoffice::AppService.email_api_key(last_request).must_equal ENV["POSTMARK_API_KEY"]
    end

  end

end
