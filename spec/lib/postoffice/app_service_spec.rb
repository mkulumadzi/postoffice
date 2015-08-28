require 'rack/test'
require_relative '../../spec_helper'

include Rack::Test::Methods

def app
  Sinatra::Application
end

describe Postoffice::AppService do

	Mongoid.load!('config/mongoid.yml')

  before do
    @person1 = create(:person, username: random_username)
    @person2 = create(:person, username: random_username)
    @person3 = create(:person, username: random_username)

    @mail1 = create(:mail, from: @person1.username, to: @person2.username)
    @mail2 = create(:mail, from: @person3.username, to: @person1.username)

    @admin_token = Postoffice::AuthService.get_admin_token
    @app_token = Postoffice::AuthService.get_app_token
    @person1_token = Postoffice::AuthService.generate_token_for_person @person1
    @person2_token = Postoffice::AuthService.generate_token_for_person @person2
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

  end

  describe 'check authorized ownership' do

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

end
