require_relative '../../spec_helper'

describe Postoffice::AuthService do

	before do
		@person = build(:person, username: random_username)
	end

	describe 'get public and private keys' do
		it 'must be able to open the private key' do
			key = Postoffice::AuthService.get_private_key
			key.private?.must_equal true
		end

		it 'must be able to open the public key' do
			key = Postoffice::AuthService.get_public_key
			key.public?.must_equal true
		end
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

		describe 'get admin token' do

			before do
				token = Postoffice::AuthService.get_admin_token
				@decoded_token = Postoffice::AuthService.decode_token(token)
			end

			it 'must have the scope for an admin user' do
				@decoded_token[0]["scope"].must_equal Postoffice::AuthService.get_scopes_for_user_type "admin"
			end

			it 'must expire in 1 hour or less' do
				assert_operator @decoded_token[0]["exp"], :<=, Time.now.to_i + 3600
			end

		end

		describe 'get app token' do

			it 'must be able to generate a token with the app scope' do
				app_token = Postoffice::AuthService.get_app_token
				decoded = Postoffice::AuthService.decode_token app_token
				decoded[0]["scope"].must_equal Postoffice::AuthService.get_scopes_for_user_type "app"
			end

		end

    describe 'tokens' do

      it 'must be able to generate a token with the admin scope' do
        admin_token = Postoffice::AuthService.get_admin_token
        decoded = Postoffice::AuthService.decode_token admin_token
        decoded[0]["scope"].must_equal Postoffice::AuthService.get_scopes_for_user_type "admin"
      end

    end

	end

	describe 'temporary test token' do

		before do
			token = Postoffice::AuthService.get_test_token
			@decoded_token = Postoffice::AuthService.decode_token token
		end

		it 'must set the scope to test' do
			@decoded_token[0]["scope"].must_equal "test"
		end

		it 'must expire in one minute or less' do
			assert_operator @decoded_token[0]["exp"], :<=, Time.now.to_i + 60
		end

	end

	describe 'send password reset email' do

		describe 'generate password reset token' do

			before do
				@token = Postoffice::AuthService.get_password_reset_token @person
			end

			describe 'generate payload or password reset' do

				before do
					@payload = Postoffice::AuthService.generate_payload_for_password_reset @person
				end

				it 'must include the person id' do
					@payload[:id].must_equal @person.id.to_s
				end

				it 'must be limited to the reset-password scope' do
					@payload[:scope].must_equal "reset-password"
				end

				it 'must expire in 24 hours or less' do
					assert_operator @payload[:exp], :<=, Time.now.to_i + 3600 * 24
				end

			end

			it 'must return a string' do
				@token.must_be_instance_of String
			end

			it 'must include details from the password reset payload, including the expiration date' do
				decoded_token = Postoffice::AuthService.decode_token @token
				payload =  Postoffice::AuthService.generate_payload_for_password_reset @person
				decoded_token[0]["exp"].must_equal payload[:exp]
			end

		end

		describe 'get password reset email hash' do

			before do
				@token = Postoffice::AuthService.get_password_reset_token @person
				@email_hash = Postoffice::AuthService.get_password_reset_email_hash @person, @token
			end

			it 'must return a hash' do
				@email_hash.must_be_instance_of Hash
			end

			it 'must be from the postman' do
				@email_hash[:from].must_equal ENV["POSTOFFICE_POSTMAN_EMAIL_ADDRESS"]
			end

			it 'must be to the person' do
				@email_hash[:to].must_equal @person.email
			end

			it 'must have the correct subject' do
				@email_hash[:subject].must_equal "We received a request to reset your password"
			end

			it 'must have generated the password reset email message' do
				@email_hash[:html_body].must_equal Postoffice::EmailService.generate_email_message_body('resources/password_reset_email_template.html', Hash(person: @person, token: @token))
			end

			it 'must be configured to track opens' do
				@email_hash[:track_opens].must_equal true
			end

			it 'must include the slowpost banner image as an attachment' do
				@email_hash[:attachments][0]["ContentID"].must_equal "cid:resources/slowpost_banner.png"
			end

		end

		it 'must send the email without errors' do
			result = Postoffice::AuthService.send_password_reset_email @person
			result[:error_code].must_equal 0
		end

	end

	describe 'send password email validation email if necessary' do

		it 'must not send the email if the email address has already been validated' do
			person = build(:person, username: random_username)
			person.email_address_validated = true
			Postoffice::AuthService.send_email_validation_email_if_necessary(person).must_equal nil
		end

		describe 'get email validation token' do

			before do
				@token = Postoffice::AuthService.get_email_validation_token @person
			end

			describe 'generate payload for email validation' do

				before do
					@payload = Postoffice::AuthService.generate_payload_for_email_validation @person
				end

				it 'must include the person id' do
					@payload[:id].must_equal @person.id.to_s
				end

				it 'must be limited to the validate-email scope' do
					@payload[:scope].must_equal "validate-email"
				end

				it 'must expire in 24 hours or less' do
					assert_operator @payload[:exp], :<=, Time.now.to_i + 3600 * 24
				end

			end

			it 'must return a string' do
				@token.must_be_instance_of String
			end

			it 'must include details from the email validation payload, including the expiration date' do
				decoded_token = Postoffice::AuthService.decode_token @token
				payload =  Postoffice::AuthService.generate_payload_for_email_validation @person
				decoded_token[0]["exp"].must_equal payload[:exp]
			end

		end

		describe 'get email validation email hash' do

			before do
				@token = Postoffice::AuthService.get_email_validation_token @person
				@email_hash = Postoffice::AuthService.get_email_validation_hash @person, @token
			end

			it 'must return a hash' do
				@email_hash.must_be_instance_of Hash
			end

			it 'must be from the postman' do
				@email_hash[:from].must_equal ENV["POSTOFFICE_POSTMAN_EMAIL_ADDRESS"]
			end

			it 'must be to the person' do
				@email_hash[:to].must_equal @person.email
			end

			it 'must have the correct subject' do
				@email_hash[:subject].must_equal "Please validate your email address"
			end

			it 'must have generated the email validation email message' do
				@email_hash[:html_body].must_equal Postoffice::EmailService.generate_email_message_body('resources/validate_email_template.html', Hash(person: @person, token: @token))
			end

			it 'must be configured to track opens' do
				@email_hash[:track_opens].must_equal true
			end

			it 'must include the Slowpost banner image as an attachment' do
				@email_hash[:attachments][0]["ContentID"].must_equal "cid:resources/slowpost_banner.png"
			end

		end

		it 'must send the email without errors' do
			result = Postoffice::AuthService.send_email_validation_email_if_necessary @person
			result[:error_code].must_equal 0
		end

	end

	describe 'check if a token is invalid' do

		before do
			@token1 = Postoffice::AuthService.get_password_reset_token @person
			db_token1 = Postoffice::Token.new(value: @token1)
			db_token1.save
			db_token1.mark_as_invalid
		end

		it 'must return true if the token is invalid' do
			Postoffice::AuthService.token_is_invalid(@token1).must_equal true
		end

		it 'must return false if the token is valid' do
			person2 = build(:person, username: random_username)
			token2 = Postoffice::AuthService.get_password_reset_token person2
			db_token2 = Postoffice::Token.new(value: token2)
			db_token2.save
			Postoffice::AuthService.token_is_invalid(token2).must_equal false
		end

		it 'must return false if the token has not been saved to the database yet' do
			person3 = build(:person, username: random_username)
			token3 = Postoffice::AuthService.get_password_reset_token person3
			Postoffice::AuthService.token_is_invalid(token3).must_equal false
		end

	end

end
