require_relative '../../spec_helper'

describe Postoffice::AuthService do

	Mongoid.load!('config/mongoid.yml')

	before do
		@person = build(:person, username: random_username)
	end

	it 'must be able to open the private key' do
		key = Postoffice::AuthService.get_private_key
		key.private?.must_equal true
	end

	it 'must be able to open the public key' do
		key = Postoffice::AuthService.get_public_key
		key.public?.must_equal true
	end

  describe 'get scope by user type' do

    it 'must return the correct scope for a person' do
      scope = Postoffice::AuthService.get_scopes_for_user_type "person"
      scope.must_equal "can-read can-write"
    end

    it 'must return the scope for an app' do
      scope = Postoffice::AuthService.get_scopes_for_user_type "app"
      scope.must_equal "create-person reset-password"
    end

    it 'must return the scope for an admin' do
      scope = Postoffice::AuthService.get_scopes_for_user_type "admin"
      scope.must_equal "admin can-read can-write create-person reset-password bulk-search can-upload get-image"
    end

    it 'must return nil for an unrecognized user type' do
      scope = Postoffice::AuthService.get_scopes_for_user_type "foo"
      scope.must_equal nil
    end

  end

	describe 'generate a token' do

    before do
      @payload = {:data => "test"}
      @token = Postoffice::AuthService.generate_token @payload
    end

    it 'must return the token as a string' do
      @token.must_be_instance_of String
    end

    describe 'decode a token' do

      before do
        @token_decoded = Postoffice::AuthService.decode_token @token
      end

      it 'must return an array' do
        @token_decoded.must_be_instance_of Array
      end

      it 'must include the payload in the first item of the array, with symbols converted to strings' do
        @token_decoded[0]["data"].must_equal "test"
      end

    end

    describe 'expiring token' do

      it 'must generate an expiration date that is 3 months in the future' do
        expiration_integer = Postoffice::AuthService.generate_expiration_date_for_token
        just_less_than_3_months = Time.now.to_i + 3600 * 24 * 72 - 60
        assert_operator expiration_integer, :>=, just_less_than_3_months
      end

    end

    describe 'token for a person' do

      describe 'generate the payload for the person' do

        describe 'the payload' do

          before do
            @payload = Postoffice::AuthService.generate_payload_for_person @person
          end

          it 'must return a hash with the user id as a string' do
            @payload[:id].must_equal @person.id.to_s
          end

          it 'must also return the expiration date as an integer' do
            @payload[:exp].must_be_instance_of Fixnum
          end

          it 'must return the scope for a person' do
            @payload[:scope].must_equal "can-read can-write"
          end

        end

      end

      describe 'generate the token for the person' do

    		before do
    			@token = Postoffice::AuthService.generate_token_for_person @person
    		end

    		it 'must return the token as a string' do
    			@token.must_be_instance_of String
    		end

    		it 'must return a token that can be decoded to get the payload' do
          decoded_token = Postoffice::AuthService.decode_token @token
    			decoded_token[0]["id"].must_equal @person.id.to_s
    		end

      end

    end

    describe 'apps and admins' do

      describe 'payloads' do

        before do
          @payload = Postoffice::AuthService.generate_payload_for_user_type "admin"
        end

        it 'must create a payload for an admin that includes the scope' do
          @payload[:scope].must_equal Postoffice::AuthService.get_scopes_for_user_type "admin"
        end

        it 'must not expire' do
          @payload[:exp].must_equal nil
        end

        it 'must work for user type app' do
          payload = Postoffice::AuthService.generate_payload_for_user_type "app"
          payload[:scope].must_equal Postoffice::AuthService.get_scopes_for_user_type "app"
        end

      end

    end

    describe 'tokens' do

      it 'must be able to generate a token with the admin scope' do
        admin_token = Postoffice::AuthService.get_admin_token
        decoded = Postoffice::AuthService.decode_token admin_token
        decoded[0]["scope"].must_equal Postoffice::AuthService.get_scopes_for_user_type "admin"
      end

      it 'must be able to generate a token with the app scope' do
        app_token = Postoffice::AuthService.get_app_token
        decoded = Postoffice::AuthService.decode_token app_token
        decoded[0]["scope"].must_equal Postoffice::AuthService.get_scopes_for_user_type "app"
      end

    end

		describe 'temporary password reset token' do

			describe 'payload' do

				before do
					@payload = Postoffice::AuthService.generate_payload_for_password_reset @person
				end

				it 'must include the person id' do
					@payload[:id].must_equal @person.id.to_s
				end

				it 'must be limited to the reset-password scope' do
					@payload[:scope].must_equal "reset-password"
				end

				it 'must expire in 24 hours' do
					@payload[:exp].must_equal Time.now.to_i + 3600 * 24
				end

			end

			describe 'token' do

				before do
					token = Postoffice::AuthService.generate_password_reset_token @person
					@token_payload = Postoffice::AuthService.decode_token token
				end

				it 'must generate a JWT token' do
					@token_payload[1]["typ"].must_equal "JWT"
				end

				it 'must include the password_reset_payload for the person, including a token that will expire in 24 hours' do
					@token_payload[0]["exp"].must_equal Time.now.to_i + 3600 * 24
				end

			end

		end

	end

end
