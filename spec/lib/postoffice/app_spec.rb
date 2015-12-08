require 'rack/test'
require 'minitest/autorun'
require_relative '../../spec_helper'

include Rack::Test::Methods

def app
  Sinatra::Application
end

describe app do

	before do
		@person1 = create(:person, username: random_username)
		@person2 = create(:person, username: random_username)
		@person3 = create(:person, username: random_username)

		@mail1 = create(:mail, correspondents: [build(:from_person, person_id: @person1.id), build(:to_person, person_id: @person2.id)])
		@mail2 = create(:mail, correspondents: [build(:from_person, person_id: @person1.id), build(:to_person, person_id: @person2.id)])

    @convo_1 = @mail1.conversation

		@mail3 = create(:mail, correspondents: [build(:from_person, person_id: @person3.id), build(:to_person, person_id: @person1.id)])

    @convo_2 = @mail3.conversation

		@mail4 = build(:mail, correspondents: [build(:from_person, person_id: @person1.id), build(:to_person, person_id: @person2.id)])

    @admin_token = Postoffice::AuthService.get_admin_token
    @app_token = Postoffice::AuthService.get_app_token
    @person1_token = Postoffice::AuthService.generate_token_for_person @person1
    @person2_token = Postoffice::AuthService.generate_token_for_person @person2
	end

	describe 'APNS configuration' do

		it 'must set the port to 2195' do
			APNS.port.must_equal 2195
		end

		it 'must set the gateway' do
			APNS.host.must_equal 'gateway.sandbox.push.apple.com'
		end

		it 'must point to a pem file' do
			File.exist?(APNS.pem).must_equal true
		end

	end


	describe 'app_root' do

		describe 'get /' do

			it 'must say hello world' do
				get '/'
				last_response.body.must_equal "Hello World!"
			end

      it 'must say What a Beautiful Morning if the reuest is for v2' do
        get '/', nil, {"CONTENT_TYPE" => "application/vnd.postoffice.v2+json"}
        last_response.body.must_equal "What a Beautiful Morning"
      end

		end

		describe 'POSTOFFICE_BASE_URL' do
			it 'must have a value for Postoffice BASE URL' do
				ENV['POSTOFFICE_BASE_URL'].must_be_instance_of String
			end
		end

	end

  describe 'check options' do

    before do
      options "/"
    end

    it 'must indicate that any origin is allowed' do
      last_response.headers["Access-Control-Allow-Origin"].must_equal "*"
    end

    it 'must indicate that GET, POST and OPTIONS are allowed' do
      last_response.headers["Allow"].must_equal "GET,POST,OPTIONS"
    end

    it 'must indicate which headers are allowed' do
        last_response.headers["Access-Control-Allow-Headers"].must_equal "X-Requested-With, X-HTTP-Method-Override, Content-Type, Cache-Control, Accept, Authorization, Access-Control-Allow-Credentials"
    end

  end

  describe 'get /available' do

    describe 'look for a field that can be checked (username, email, phone)' do

      describe 'unauthorized request' do

        it 'must return a 401 status' do
          get "/available?username=user"
          last_response.status.must_equal 401
        end
      end

      describe 'valid parameters' do

        before do
          get "/available?username=availableusername", nil, {"HTTP_AUTHORIZATION" => "Bearer #{@app_token}"}
        end

        it 'must return a 200 status code' do
          last_response.status.must_equal 200
        end

        it 'must return a JSON response indicating whether or not the field is valid' do
          result = JSON.parse(last_response.body)
          result.must_equal Hash["username", "available"]
        end

      end

      describe 'invalid parameters' do

        before do
          get "/available?name=Evan%20Waters", nil, {"HTTP_AUTHORIZATION" => "Bearer #{@app_token}"}
        end

        it 'must return a 404 status if the parameters cannot be checked' do
          last_response.status.must_equal 404
        end

        it 'must return an empty response body' do
          last_response.body.must_equal ""
        end

      end

    end

  end

	describe 'post /person/new' do

    describe 'create a person' do

  		before do
  			@username = random_username
  			data = '{"username": "' + @username + '", "phone": "' + random_phone + '", "email": "' + random_email + '", "password": "password"}'
  			post "/person/new?test=true", data, {"HTTP_AUTHORIZATION" => "Bearer #{@app_token}"}
  		end

  		it 'must return a 201 status code' do
  			last_response.status.must_equal 201
  		end

  		it 'must return an empty body' do
  			last_response.body.must_equal ""
  		end

  		it 'must include a link to the person in the header' do
  			assert_match(/#{ENV['POSTOFFICE_BASE_URL']}\/person\/id\/\w{24}/, last_response.header["location"])
  		end

  		describe 'welcome message' do

  			before do
          person = Postoffice::Person.find_by(username: @username)
          @welcome_mail = Postoffice::Mail.where(:correspondents.elem_match => { :_type => "Postoffice::ToPerson", :person_id => person.id}).first
          @postman = Postoffice::Person.find_by(username: ENV['POSTOFFICE_POSTMAN_USERNAME'])
  			end

  			it 'must generate a welcome message from the Postoffice Postman' do
  				@welcome_mail.from_person.must_equal @postman
  			end

  		end

    end

		describe 'duplicate username' do

			before do
				data = '{"username": "' + @person1.username + '", "phone": "' + random_phone + '", "email": "' + random_email + '", "password": "password"}'
				post "/person/new", data, {"HTTP_AUTHORIZATION" => "Bearer #{@app_token}"}
			end

			it 'must return a 403 error' do
				last_response.status.must_equal 403
			end

			it 'must return the correct error message' do
				response = JSON.parse(last_response.body)
				response["message"].must_equal "An account with that username already exists!"
			end

		end

		describe 'duplicate email' do

			before do
				data = '{"username": "' + random_username + '", "phone": "' + random_phone + '", "email": "' + @person1.email + '", "password": "password"}'
				post "/person/new", data, {"HTTP_AUTHORIZATION" => "Bearer #{@app_token}"}
			end

			it 'must return a 403 error if a duplicate email is posted' do
				last_response.status.must_equal 403
			end

			it 'must return the correct error message' do
				response = JSON.parse(last_response.body)
				response["message"].must_equal "An account with that email already exists!"
			end

		end

		describe 'duplicate phone' do

			before do
				data = '{"username": "' + random_username + '", "phone": "' + @person1.phone + '", "email": "' + random_email + '", "password": "password"}'
				post "/person/new", data, {"HTTP_AUTHORIZATION" => "Bearer #{@app_token}"}
			end

			it 'must return a 403 error if a duplicate phone is posted' do
				last_response.status.must_equal 403
			end

			it 'must return the correct error message' do
				response = JSON.parse(last_response.body)
				response["message"].must_equal "An account with that phone number already exists!"
			end

		end

		describe 'no username' do

			before do
				data = '{"phone": "' + random_phone + '", "email": "' + random_email + '", "password": "password"}'
				post "/person/new", data, {"HTTP_AUTHORIZATION" => "Bearer #{@app_token}"}
			end

			it 'must return a 403 error if no username is posted' do
				last_response.status.must_equal 403
			end

			it 'must return the correct error message' do
				response = JSON.parse(last_response.body)
				response["message"].must_equal "Missing required field: username"
			end

		end

		describe 'no email' do

			before do
				data = '{"username": "' + random_username + '", "phone": "' + random_phone + '", "password": "password"}'
				post "/person/new", data, {"HTTP_AUTHORIZATION" => "Bearer #{@app_token}"}
			end

			it 'must return a 403 error if no email is posted' do
				last_response.status.must_equal 403
			end

			it 'must return the correct error message' do
				response = JSON.parse(last_response.body)
				response["message"].must_equal "Missing required field: email"
			end

		end

		describe 'no password' do

			before do
				data = '{"username": "' + random_username + '", "email": "' + random_email + '", "phone": "' + random_phone + '", "password": ""}'
				post "/person/new", data, {"HTTP_AUTHORIZATION" => "Bearer #{@app_token}"}
			end

			it 'must return a 403 error if no password is posted' do
				last_response.status.must_equal 403
			end

			it 'must return the correct error message' do
				response = JSON.parse(last_response.body)
				response["message"].must_equal "Missing required field: password"
			end

		end

    describe 'unauthorized request' do

      it 'must return a 401 status if the request is not authorized' do
        username = random_username
        data = '{"username": "' + username + '", "phone": "' + random_phone + '", "email": "' + random_email + '", "password": "password"}'
        post "/person/new", data, {"HTTP_AUTHORIZATION" => "Bearer #{@person1_token}"}
        last_response.status.must_equal 401
      end
    end

	end

	describe '/person/id/:id' do

		describe 'get /person/id/:id' do

      describe 'record found' do

  			before do
  				get "/person/id/#{@person1.id}", nil, {"HTTP_AUTHORIZATION" => "Bearer #{@person1_token}"}
  				@response = JSON.parse(last_response.body)
  			end

  			it 'must return a 200 status code' do
  				last_response.status.must_equal 200
  			end

  			it 'must return the expected fields' do
  				@response.must_equal expected_json_fields_for_person(@person1)
  			end

      end

      describe 'handle IF_MODIFIED_SINCE' do

        describe 'record has been modified since date specified' do

          before do
            if_modified_since = (@person1.updated_at - 5.days).to_s
            get "/person/id/#{@person1.id}", nil, {"HTTP_AUTHORIZATION" => "Bearer #{@person1_token}", "HTTP_IF_MODIFIED_SINCE" => if_modified_since}
            @response = JSON.parse(last_response.body)
          end

          it 'must have a 200 status code' do
            last_response.status.must_equal 200
          end

          it 'must return the person record if the IF_MODIFIED_SINCE date is earlier' do
            @response.must_equal expected_json_fields_for_person(@person1)
          end

        end

        describe 'record has not been modified since date specified' do

          before do
            if_modified_since = (@person1.updated_at).to_s
            get "/person/id/#{@person1.id}", nil, {"HTTP_AUTHORIZATION" => "Bearer #{@person1_token}", "HTTP_IF_MODIFIED_SINCE" => if_modified_since}
          end

          it 'must have a 304 status code' do
            last_response.status.must_equal 304
          end

          it 'must return an empty response body' do
            last_response.body.must_equal ""
          end

        end

      end

  		describe 'resource not found' do

  			before do
  				get "person/id/abc", nil, {"HTTP_AUTHORIZATION" => "Bearer #{@admin_token}"}
  			end

  			it 'must return 404 if the person is not found' do
  				last_response.status.must_equal 404
  			end

  			it 'must return an empty response body if the person is not found' do
  				last_response.body.must_equal ""
  			end

  		end

      describe "unauthorized request" do

        it 'must return a 401 status if the request is not authorized' do
          get "/person/id/#{@person1.id}"
          last_response.status.must_equal 401
        end

      end

    end

		describe 'post /person/id/:id' do

			before do
				data = '{"city": "New York", "state": "NY"}'
				post "person/id/#{@person1.id}?test=true", data, {"HTTP_AUTHORIZATION" => "Bearer #{@person1_token}"}
			end

			it 'must return a 204 status code' do
				last_response.status.must_equal 204
			end

			it 'must update the person record' do
				person = Postoffice::Person.find(@person1.id)
				person.city.must_equal "New York"
			end

			it 'must not void fields that are not included in the update' do
				person = Postoffice::Person.find(@person1.id)
				person.given_name.must_equal @person1.given_name
			end

		end

		describe 'prevent invalid updates' do

			it 'must return a 403 status if the username is attempted to be updated' do
				data = '{"username": "new_username"}'
				post "person/id/#{@person1.id}?test=true", data, {"HTTP_AUTHORIZATION" => "Bearer #{@person1_token}"}
				last_response.status.must_equal 403
			end

      describe 'duplicate an existing email address' do

        before do
          personA = create(:person, username: random_username, email: "#{random_username}@test.com")
          personB = create(:person, username: random_username, email: "#{random_username}@test.com")
          data = '{"email": "' + personA.email + '"}'
          post "person/id/#{personB.id}?test=true", data, {"HTTP_AUTHORIZATION" => "Bearer #{@admin_token}"}
        end

        it 'must return a 403 error if the update would duplicate an existing email address' do
          last_response.status.must_equal 403
        end

        it 'must return an error message in the response body' do
          message = JSON.parse(last_response.body)["message"]
          message.must_be_instance_of String
        end

      end

		end

    describe 'unauthorized request' do

      it 'must return a 401 status if a user tries to update another person record' do
        data = '{"city": "New York", "state": "NY"}'
        post "person/id/#{@person2.id}", data, {"HTTP_AUTHORIZATION" => "Bearer #{@person1_token}"}
        last_response.status.must_equal 401
      end

    end

    describe 'authorize admin' do

      it 'must allow the admin to updtae a person record' do
        data = '{"city": "New York", "state": "NY"}'
        post "person/id/#{@person2.id}", data, {"HTTP_AUTHORIZATION" => "Bearer #{@admin_token}"}
        last_response.status.must_equal 204
      end

    end

	end

	describe '/login' do

		describe 'successful login' do

			before do
				# Creating a person with a password to test login
				person_attrs = attributes_for(:person)
				data = Hash["username", random_username, "name", person_attrs[:name], "email", random_email, "phone", random_phone, "password", "password"]
				@user = Postoffice::PersonService.create_person data

				data = '{"username": "' + @user.username + '", "password": "password"}'
				post "/login", data
				@response = JSON.parse(last_response.body)
			end

			it 'must return a 200 status code' do
				last_response.status.must_equal 200
			end

      describe 'response body' do

        it 'must include the token in the response body' do
          @response["access_token"].must_be_instance_of String
        end

  			it 'must include the person record in the response body, including the id' do
  				BSON::ObjectId.from_string(@response["person"]["_id"]["$oid"]).must_equal @user.id
  			end

      end

			describe 'incorrect password' do

				it 'must return a 401 status code for an incorrect password' do
					data = '{"username": "' + @user.username + '", "password": "wrong_password"}'
					post "/login", data
					last_response.status.must_equal 401
				end

			end

		end

		describe 'unrecognized username' do

			before do
				data = '{"username": "unrecognized_username", "password": "wrong_password"}'
				post "/login", data
			end

			it 'must return a 401 status code for an unrecognized username' do
				last_response.status.must_equal 401
			end

		end

	end

  describe '/login/facebook' do

    describe 'successful login' do

      before do
        @fb_person = create(:person, username: random_username, email: "#{random_username}@test.com", facebook_id: "123")
        data = '{"email": "' + @fb_person.email + '", "facebook_id": "123"}'
        post "/login/facebook", data
        @response = JSON.parse(last_response.body)
      end

      it 'must return a 200 status code' do
        last_response.status.must_equal 200
      end

      describe 'response body' do

        it 'must include the token in the response body' do
          @response["access_token"].must_be_instance_of String
        end

        it 'must include the person record in the response body, including the id' do
          BSON::ObjectId.from_string(@response["person"]["_id"]["$oid"]).must_equal @fb_person.id
        end

      end

      describe 'incorrect facebook_id' do

        it 'must return a 401 status code for an incorrect facebook_id' do
          data = '{"email": "' + @fb_person.email + '", "facebook_id": "abc"}'
          post "/login/facebook", data
          last_response.status.must_equal 401
        end

      end

    end

    describe 'unrecognized email' do

      before do
        data = '{"email": "unrecognized_email", "facebook_id": "123"}'
        post "/login/facebook", data
      end

      it 'must return a 401 status code for an unrecognized email' do
        last_response.status.must_equal 401
      end

    end

  end

	describe '/person/id/:id/reset_password' do

		before do
			person_attrs = attributes_for(:person)
			data = Hash["username", random_username, "name", person_attrs[:name], "email", random_email, "phone", random_phone, "password", "password"]
			@person = Postoffice::PersonService.create_person data
		end

		describe 'submit the correct old password and a valid new password' do

			before do
				data = '{"old_password": "password", "new_password": "password123"}'
				post "/person/id/#{@person.id.to_s}/reset_password", data, {"HTTP_AUTHORIZATION" => "Bearer #{@app_token}"}
			end

			it 'must return a 204 status code' do
				last_response.status.must_equal 204
			end

			it 'must reset the password' do
				person_record = Postoffice::Person.find(@person.id)
				person_record.hashed_password.must_equal Postoffice::LoginService.hash_password "password123", person_record.salt
			end

			it 'must return an empty response body' do
				last_response.body.must_equal ""
			end

		end

		describe 'error conditions' do

			it 'must return a 404 error if the person record cannot be found' do
				data = '{"old_password": "password", "new_password": "password123"}'
				post "/person/id/abc123/reset_password", data, {"HTTP_AUTHORIZATION" => "Bearer #{@app_token}"}

				last_response.status.must_equal 404
			end

			describe 'Runtime errors' do

				before do
					#Example case: Submit wrong password
					data = '{"old_password": "wrongpassword", "new_password": "password123"}'
					post "/person/id/#{@person.id.to_s}/reset_password", data, {"HTTP_AUTHORIZATION" => "Bearer #{@app_token}"}
				end

				it 'must return a 403 error' do
					last_response.status.must_equal 403
				end

				it 'must return a message indicating why the operation could not be completed' do
					response_body = JSON.parse(last_response.body)
					response_body["message"].must_equal "Existing password is incorrect"
				end

			end

		end

    describe 'unauthorized request' do
      it 'must return a 401 status if the request is not authorized' do
        data = '{"old_password": "password", "new_password": "password123"}'
        post "/person/id/#{@person.id.to_s}/reset_password", data, {"HTTP_AUTHORIZATION" => "Bearer #{@person1_token}"}
        last_response.status.must_equal 401
      end
    end

	end

  describe '/validate_email' do

    before do
      @token = Postoffice::AuthService.get_email_validation_token @person1
      post "/validate_email", nil, {"HTTP_AUTHORIZATION" => "Bearer #{@token}"}
    end

    it 'must return an Access-Control-Allow-Origin header' do
      last_response.headers["Access-Control-Allow-Origin"].must_equal "*"
    end

    it 'must return a 204 status' do
      last_response.status.must_equal 204
    end

    it 'must mark the email address as valid' do
      person = Postoffice::Person.find(@person1.id)
      person.email_address_validated.must_equal true
    end

    it 'must flag the token as invalid so that it cannot be used again' do
      db_token = Postoffice::Token.find_by(value: @token)
      db_token.is_invalid.must_equal true
    end

    describe 'error conditions' do

      it 'must return a 401 status if the token has expired' do
        payload = Postoffice::AuthService.generate_payload_for_email_validation @person1
        payload[:exp] = Time.now.to_i - 60
        token = Postoffice::AuthService.generate_token payload
        post "/validate_email", nil, {"HTTP_AUTHORIZATION" => "Bearer #{token}"}

        last_response.status.must_equal 401
      end

      it 'must return a 401 status if the token does not have the validate-email scope' do
        post "/validate_email", nil, {"HTTP_AUTHORIZATION" => "Bearer #{@person1_token}"}
        last_response.status.must_equal 401
      end

      it 'must return a 401 status if the same token is used twice' do
        token = Postoffice::AuthService.get_email_validation_token @person1
        post "/validate_email", nil, {"HTTP_AUTHORIZATION" => "Bearer #{token}"}
        post "/validate_email", nil, {"HTTP_AUTHORIZATION" => "Bearer #{token}"}
        last_response.status.must_equal 401
      end

    end

  end

  describe '/reset_password' do

    before do
      @token = Postoffice::AuthService.get_password_reset_token @person1
      data = '{"password": "password123"}'
      post "/reset_password", data, {"HTTP_AUTHORIZATION" => "Bearer #{@token}"}
    end

    it 'must return an Access-Control-Allow-Origin header' do
      last_response.headers["Access-Control-Allow-Origin"].must_equal "*"
    end

    it 'must return a 204 status' do
      last_response.status.must_equal 204
    end

    it 'must reset the password' do
      new_person_record = Postoffice::Person.find(@person1.id)
      new_person_record.hashed_password.must_equal Postoffice::LoginService.hash_password "password123", new_person_record.salt
    end

    it 'must flag the token as invalid so that it cannot be used again' do
      db_token = Postoffice::Token.find_by(value: @token)
      db_token.is_invalid.must_equal true
    end

    describe 'error conditions' do

      it 'must return a 401 status if the token has expired' do
        payload = Postoffice::AuthService.generate_payload_for_password_reset @person1
        payload[:exp] = Time.now.to_i - 60
        token = Postoffice::AuthService.generate_token payload
        data = '{"password": "password123"}'
        post "/reset_password", data, {"HTTP_AUTHORIZATION" => "Bearer #{token}"}

        last_response.status.must_equal 401
      end

      it 'must return a 401 status if the token does not have the reset-password scope' do
        data = '{"password": "password123"}'
        post "/reset_password", data, {"HTTP_AUTHORIZATION" => "Bearer #{@person1_token}"}
        last_response.status.must_equal 401
      end

      it 'must return a 401 status if the same token is used twice' do
        token = Postoffice::AuthService.get_password_reset_token @person1
        data = '{"password": "password123"}'
        post "/reset_password", data, {"HTTP_AUTHORIZATION" => "Bearer #{token}"}
        post "/reset_password", data, {"HTTP_AUTHORIZATION" => "Bearer #{token}"}
        last_response.status.must_equal 401
      end

      it 'must return a 403 status if the data does not include a "password" field' do
        token = Postoffice::AuthService.get_password_reset_token @person2
        data = '{"wrong": "password123"}'
        post "/reset_password", data, {"HTTP_AUTHORIZATION" => "Bearer #{token}"}
        last_response.status.must_equal 403
      end

    end

  end

  describe 'request password reset token' do

    describe 'successful request' do

      before do
        data = '{"email": "' + @person1.email + '"}'
        post "/request_password_reset?test=true", data, {"HTTP_AUTHORIZATION" => "Bearer #{@app_token}"}
      end

      it 'must return a 201 status' do
        last_response.status.must_equal 201
      end

      it 'must return an empty response' do
        last_response.body.must_equal ""
      end

    end

    describe 'email does not match an account' do

      before do
        data = '{"email": "notanemail@notaprovider.com"}'
        post "/request_password_reset", data, {"HTTP_AUTHORIZATION" => "Bearer #{@app_token}"}
      end

      it 'must return a 404 status' do
        last_response.status.must_equal 404
      end

      it 'must return an error message' do
        response = JSON.parse(last_response.body)
        response["message"].must_equal "An account with that email does not exist."
      end

    end

    ## This works; can't test it without sending a real email, don't want to do that in a test...
    # describe 'email has been marked inactive' do
    #
    #   before do
    #     data = '{"email": "' + @person1.email + '"}'
    #     post "/request_password_reset", data, {"HTTP_AUTHORIZATION" => "Bearer #{@app_token}"}
    #   end
    #
    #   it 'must return a 403 status' do
    #     last_response.status.must_equal 403
    #   end
    #
    #   it 'must return an error message' do
    #     response = JSON.parse(last_response.body)
    #     response["message"].must_equal "Email address has been marked as inactive."
    #   end
    #
    # end

  end

	describe '/people' do

    describe 'get all people' do

      before do
      	get '/people', nil, {"HTTP_AUTHORIZATION" => "Bearer #{@admin_token}"}
      end

  		it 'must return a 200 status code' do
  			last_response.status.must_equal 200
  		end

  		it 'must return a collection with all of the people if no parameters are entered' do
  			collection = JSON.parse(last_response.body)
  			num_people = Postoffice::Person.count
  			collection.length.must_equal num_people
  		end

  		it 'must return a filtered collection if parameters are given' do
  			get "/people?name=Evan", nil, {"HTTP_AUTHORIZATION" => "Bearer #{@admin_token}"}
  			expected_number = Postoffice::Person.where(name: "Evan").count
  			actual_number = JSON.parse(last_response.body).count
  			actual_number.must_equal expected_number
  		end

  		it 'must return the expected information for a person record' do
  			get "/people?id=#{@person1.id}", nil, {"HTTP_AUTHORIZATION" => "Bearer #{@admin_token}"}
  			people_response = JSON.parse(last_response.body)

  			people_response[0].must_equal expected_json_fields_for_person(@person1)
  		end

    end

    describe 'get only records that were created or updated after a specific date and time' do

      before do
        @person4 = create(:person, username: random_username)
        person_record = Postoffice::Person.find(@person3.id)
        @timestamp = person_record.updated_at
        @timestamp_string = JSON.parse(person_record.as_document.to_json)["updated_at"]
        get "/people", nil, {"HTTP_IF_MODIFIED_SINCE" => @timestamp_string, "HTTP_AUTHORIZATION" => "Bearer #{@admin_token}"}
      end

      it 'must include the timestamp in the header' do
        last_request.env["HTTP_IF_MODIFIED_SINCE"].must_equal @timestamp
      end

      it 'must only return people records that were created or updated after the timestamp' do
        num_returned = JSON.parse(last_response.body).count
        expected_number = Postoffice::Person.where({updated_at: { "$gt" => @timestamp } }).count
        num_returned.must_equal expected_number
      end

    end

    describe 'unauthorized request' do
      it 'must return a 401 status if the request is not authorized' do
        get "/people", nil, {"HTTP_AUTHORIZATION" => "Bearer #{@app_token}"}
        last_response.status.must_equal 401
      end
    end

	end

	describe '/person/id/:id/mail/new' do

		before do
      @data = '{"correspondents": {"to_people": ["' + @person2.id.to_s + '"], "emails": ["test@test.com", "test2@test.com"]}, "attachments": {"notes": ["Hey what is up"]}}'
		end

		describe 'post /person/id/:id/mail/new' do

			before do
				post "/person/id/#{@person1.id}/mail/new", @data, {"HTTP_AUTHORIZATION" => "Bearer #{@person1_token}"}
			end

			it 'must get a status of 201 when the mail is created' do
				last_response.status.must_equal 201
			end

			it 'must return an empty body' do
				last_response.body.must_equal ""
			end

			it 'must include a link to the mail in the header' do
				assert_match(/#{ENV['POSTOFFICE_BASE_URL']}\/mail\/id\/\w{24}/, last_response.header["location"])
			end

		end

		describe 'post mail for a person that does not exist' do

			before do
				from_id = 'abc'
				post "/person/id/#{from_id}/mail/new", @data, {"HTTP_AUTHORIZATION" => "Bearer #{@admin_token}"}
			end

			it 'should return a 404 status' do
				last_response.status.must_equal 404
			end

			it 'should return an empty response body' do
				last_response.body.must_equal ""
			end

		end

    describe 'unauthorized request' do

      it 'must return a 401 error if a person tries to create mail for another user id' do
        post "/person/id/#{@person2.id}/mail/new", @data, {"HTTP_AUTHORIZATION" => "Bearer #{@person1_token}"}
        last_response.status.must_equal 401
      end

    end

	end

	describe '/person/id/:id/mail/send' do

		before do
      @data = '{"correspondents": {"to_people": ["' + @person2.id.to_s + '"], "emails": ["test@test.com", "test2@test.com"]}, "attachments": {"notes": ["Hey what is up"]}}'
		end

		describe 'post /person/id/:id/mail/send' do

			before do
				post "/person/id/#{@person1.id}/mail/send?test=true", @data, {"HTTP_AUTHORIZATION" => "Bearer #{@person1_token}"}
			end

			it 'must get a status of 201' do
				last_response.status.must_equal 201
			end

			it 'must return an empty body' do
				last_response.body.must_equal ""
			end

			it 'must include a link to the mail in the header' do
				assert_match(/#{ENV['POSTOFFICE_BASE_URL']}\/mail\/id\/\w{24}/, last_response.header["location"])
			end

			it 'must have sent the mail' do
				mail_id = last_response.header["location"].split("/").pop
				mail = Postoffice::Mail.find(mail_id)
				mail.status.must_equal "SENT"
			end

      it 'must have sent a preview email if this is the first time the person has sent a Slowpost by email' do
        Postoffice::QueueService.action_has_occurred?("SEND_PREVIEW_EMAIL", @person1.id).must_equal true
      end

		end

    describe 'unauthorized request' do

      it 'must return a 401 error if a person tries to create mail for another user id' do
        post "/person/id/#{@person2.id}/mail/send?test=true", @data, {"HTTP_AUTHORIZATION" => "Bearer #{@person1_token}"}
        last_response.status.must_equal 401
      end

    end

    describe 'invalid recipients' do

      before do
        @data = '{"correspondents": {"to_people": ["abc"], "emails": ["test@test.com", "test2@test.com"]}, "attachments": {"notes": ["Hey what is up"]}}'
        post "/person/id/#{@person2.id}/mail/send?test=true", @data, {"HTTP_AUTHORIZATION" => "Bearer #{@person2_token}"}
      end

      it 'must return a 403 status' do
        last_response.status.must_equal 403
      end

      it 'must return an error message in the response body' do
        message = JSON.parse(last_response.body)["message"]
        message.must_be_instance_of String
      end

    end

	end

	describe '/mail/id/:id' do

		describe 'get /mail/id/:id' do

      before do
        get "/mail/id/#{@mail1.id}", nil, {"HTTP_AUTHORIZATION" => "Bearer #{@person1_token}"}
      end

			it 'must return a 200 status code' do
				last_response.status.must_equal 200
			end

			it 'must return appropriate fields for the person from the mail in the response body' do
        expected_result = Postoffice::MailService.hash_of_mail_for_person(@mail1, @person1).to_json
				last_response.body.must_equal expected_result
			end

      describe 'admin request' do
        before do
          get "/mail/id/#{@mail1.id}", nil, {"HTTP_AUTHORIZATION" => "Bearer #{@admin_token}"}
        end

        it 'must return the complete mail document' do
          last_response.body.must_equal @mail1.as_document.to_json
        end
      end

      describe 'resource not found' do

        before do
          get "mail/id/abc", nil, {"HTTP_AUTHORIZATION" => "Bearer #{@admin_token}"}
        end

        it 'must return 404 if the mail is not found' do
          last_response.status.must_equal 404
        end

        it 'must return an empty response body if the mail is not found' do
          last_response.body.must_equal ""
        end

      end

      describe 'request authorization' do

        it 'must allow a person who sent the mail to get it' do
          mail = create(:mail, correspondents: [build(:from_person, person_id: @person1.id), build(:to_person, person_id: @person2.id)])
          get "/mail/id/#{@mail1.id}", nil, {"HTTP_AUTHORIZATION" => "Bearer #{@person1_token}"}
          last_response.status.must_equal 200
        end

        it 'must allow a person who received the mail to get it' do
          mail = create(:mail, correspondents: [build(:from_person, person_id: @person2.id), build(:to_person, person_id: @person1.id)])
          get "/mail/id/#{@mail1.id}", nil, {"HTTP_AUTHORIZATION" => "Bearer #{@person1_token}"}
          last_response.status.must_equal 200
        end

        it 'must not allow a person to get the mail if they did not send or receive it' do
          mail = create(:mail, correspondents: [build(:from_person, person_id: @person2.id), build(:to_person, person_id: @person3.id)])
          get "/mail/id/#{mail.id}", nil, {"HTTP_AUTHORIZATION" => "Bearer #{@person1_token}"}
          last_response.status.must_equal 401
        end

      end

		end

		describe 'post /mail/id/:id/send' do

			before do
				post "/mail/id/#{@mail1.id}/send", nil, {"HTTP_AUTHORIZATION" => "Bearer #{@person1_token}"}
			end

			it 'must send the mail' do
				mail = Postoffice::Mail.find(@mail1.id)
				mail.status.must_equal "SENT"
			end

			it 'must be scheduled to arrive' do
				mail = Postoffice::Mail.find(@mail1.id)
				mail.scheduled_to_arrive.must_be_instance_of DateTime
			end

			it 'must return a 204 status code' do
				last_response.status.must_equal 204
			end

			it 'must return an empty response body' do
				last_response.body.must_equal ""
			end

			describe 'try to send mail that has already been sent' do

				before do
					post "/mail/id/#{@mail1.id}/send", nil, {"HTTP_AUTHORIZATION" => "Bearer #{@person1_token}"}
				end

				it 'must return a 403 status' do
					last_response.status.must_equal 403
				end

				it 'must return an empty response body' do
					last_response.body.must_equal ""
				end

			end

		end

		describe 'send a missing piece of mail' do

			before do
				post "/mail/id/abc/send", nil, {"HTTP_AUTHORIZATION" => "Bearer #{@person1_token}"}
			end

			it 'must return 404 if the mail is not found' do
				last_response.status.must_equal 404
			end

			it 'must return an empty response body' do
				last_response.body.must_equal ""
			end

		end

    describe 'unauthorized request' do

      it 'must return a 401 status if a person tries to send a piece of mail that does not belong to them' do
        post "/mail/id/#{@mail1.id}/send", nil, {"HTTP_AUTHORIZATION" => "Bearer #{@person2_token}"}
        last_response.status.must_equal 401
      end
    end

  end

	describe 'post /mail/id/:id/deliver' do

		before do
			post "/mail/id/#{@mail1.id}/send", nil, {"HTTP_AUTHORIZATION" => "Bearer #{@person1_token}"}
			post "/mail/id/#{@mail1.id}/deliver", nil, {"HTTP_AUTHORIZATION" => "Bearer #{@person1_token}"}
		end

		it 'must have a status of DELIVERED' do
			mail = Postoffice::Mail.find(@mail1.id)
			mail.status.must_equal "DELIVERED"
		end

		it 'must return a 204 status code' do
			last_response.status.must_equal 204
		end

		it 'must return an empty response body' do
			last_response.body.must_equal ""
		end

		describe 'try to deliver mail that has not been sent' do

			before do
				post "/mail/id/#{@mail2.id}/deliver", nil, {"HTTP_AUTHORIZATION" => "Bearer #{@person1_token}"}
			end

			it 'must return a 403 status' do
				last_response.status.must_equal 403
			end

			it 'must return empty response body' do
				last_response.body.must_equal ""
			end

		end

		describe 'deliver a missing piece of mail' do

			before do
				post "/mail/id/abc/deliver", nil, {"HTTP_AUTHORIZATION" => "Bearer #{@person1_token}"}
			end

			it 'must return 404 if the mail is not found' do
				last_response.status.must_equal 404
			end

			it 'must return an empty response body' do
				last_response.body.must_equal ""
			end

		end

	end

  describe 'post /mail/id/:id/arrive_now' do

    before do
      @mail1.mail_it
      post "/mail/id/#{@mail1.id}/arrive_now", nil, {"HTTP_AUTHORIZATION" => "Bearer #{@person1_token}"}
    end

    it 'must make the mail arrive now' do
      db_record = Postoffice::Mail.find(@mail1.id)
      db_record.scheduled_to_arrive.to_i.must_equal Time.now.to_i
    end

    it 'must return a 204 status code' do
      last_response.status.must_equal 204
    end

    it 'must return an empty response body' do
      last_response.body.must_equal ""
    end

  end

	describe '/mail' do

    before do
			get '/mail', nil, {"HTTP_AUTHORIZATION" => "Bearer #{@admin_token}"}
    end

		it 'must return a 200 status code' do
			last_response.status.must_equal 200
		end

		it 'must return a collection with all of the mail if no parameters are entered' do
			response = JSON.parse(last_response.body)
			response.count.must_equal Postoffice::Mail.count
		end

		it 'must return a filtered collection if parameters are given' do
			get "/mail?status=SENT", nil, {"HTTP_AUTHORIZATION" => "Bearer #{@admin_token}"}
			response = JSON.parse(last_response.body)
			response.count.must_equal Postoffice::Mail.where(status: "SENT").count
		end

		it 'must return the expected fields for the mail' do
			get "/mail?id=#{@mail1.id}", nil, {"HTTP_AUTHORIZATION" => "Bearer #{@admin_token}"}
			response = JSON.parse(last_response.body)
			response[0].must_equal expected_json_fields_for_mail(@mail1)
		end

    describe 'get only records that were created or updated after a specific date and time' do

      before do
        @mail5 = create(:mail, correspondents: [build(:from_person, person_id: @person3.id), build(:to_person, person_id: @person1.id)])
        mail_record = Postoffice::Mail.find(@mail1.id)
        @timestamp = mail_record.updated_at
        @timestamp_string = JSON.parse(mail_record.as_document.to_json)["updated_at"]
        get "/mail", nil, {"HTTP_IF_MODIFIED_SINCE" => @timestamp_string, "HTTP_AUTHORIZATION" => "Bearer #{@admin_token}"}
      end

      it 'must include the timestamp in the header' do
        last_request.env["HTTP_IF_MODIFIED_SINCE"].must_equal @timestamp
      end

      it 'must only return records that were created or updated after the timestamp' do
        num_returned = JSON.parse(last_response.body).count
        expected_number = Postoffice::Mail.where({updated_at: { "$gt" => @timestamp } }).count
        num_returned.must_equal expected_number
      end

    end

	end

	describe '/person/id/:id/mailbox' do

		before do

			@mail1.mail_it
			@mail1.deliver

			@mail2.mail_it

      get "/person/id/#{@person2.id}/mailbox", nil, {"HTTP_AUTHORIZATION" => "Bearer #{@person2_token}"}

		end

		it 'must return a collection of mail that has arrived' do
			last_response.body.must_include @mail1.id
		end

		it 'must not return any mail that has not yet arrived' do
			last_response.body.match(/#{@mail2.id}/).must_equal nil
		end

		it 'must return the expected fields for the mail' do
			response = JSON.parse(last_response.body)
      expected_result = JSON.parse(Postoffice::MailService.hash_of_mail_for_person(@mail1, @person2).to_json)
			response[0].must_equal expected_result
		end

	end

	describe '/person/id/:id/outbox' do

		before do
			@mail1.mail_it
      get "/person/id/#{@person1.id}/outbox", nil, {"HTTP_AUTHORIZATION" => "Bearer #{@person1_token}"}
		end

		it 'must return a collection of mail that has been sent by the user' do
			last_response.body.must_include @mail1.id
		end

		it 'must not include mail that was sent by someone else' do
			last_response.body.match(/#{@mail3.id}/).must_equal nil
		end

    it 'must return the expected fields for the mail' do
			response = JSON.parse(last_response.body)
      expected_result = JSON.parse(Postoffice::MailService.hash_of_mail_for_person(@mail1, @person1).to_json)
			response[0].must_equal expected_result
		end

	end

  describe '/person/id/:id/all_mail' do

    before do

      @mail1.mail_it

      @mail3.mail_it
      @mail3.deliver

      @exclude_mail = build(:mail, correspondents: [build(:from_person, person_id: @person2.id), build(:to_person, person_id: @person1.id)])
      @exclude_mail.mail_it

      get "/person/id/#{@person1.id}/all_mail", nil, {"HTTP_AUTHORIZATION" => "Bearer #{@person1_token}"}

    end

    it 'must return a collection of mail that was sent by the user' do
      last_response.body.must_include @mail1.id
    end

    it 'must return mail sent to the user that has been delivered' do
      last_response.body.must_include @mail3.id
    end

    it 'must not return any mail sent to the user that has not yet arrived' do
      last_response.body.match(/#{@exclude_mail.id}/).must_equal nil
    end

    it 'must return the expected fields for the mail' do
      response = JSON.parse(last_response.body)
      expected_result = JSON.parse(Postoffice::MailService.hash_of_mail_for_person(@mail1, @person1).to_json)
      response[0].must_equal expected_result
    end

    describe 'get updates since a time' do

      before do
        sleep 1
        updated_time = Time.now.to_s
        @mail3.read_by @person1

        get "/person/id/#{@person1.id}/all_mail", nil, {"HTTP_AUTHORIZATION" => "Bearer #{@person1_token}", "HTTP_IF_MODIFIED_SINCE" => updated_time}

      end

      it 'must include records that were modified on or after the time' do
        last_response.body.must_include @mail3.id
      end

      it 'must not include records that were modified earlier' do
        last_response.body.include?(@mail1.id).must_equal false
      end

    end

  end

  describe '/person/id/:id/conversations' do

    before do
      @mail1.mail_it
      @mail1.deliver
      @conversation = @mail1.conversation
    end

    describe 'get conversation metadata' do

      describe 'get the metadata' do

        before do
          get "/person/id/#{@person2.id}/conversations", nil, {"HTTP_AUTHORIZATION" => "Bearer #{@person2_token}"}
          @metadata = JSON.parse(last_response.body)
        end

        it 'must return a 200 status if the conversation metadata is fetched successfully' do
          last_response.status.must_equal 200
        end

        it 'must return an array of conversation metadata' do
          hash = @mail1.conversation.metadata_for_person(@person2)
          hash_keys_as_strings = []
          hash.keys.each { |key| hash_keys_as_strings << key.to_s }
          @metadata[0].keys.must_equal hash_keys_as_strings
        end

      end

      describe 'error conditions' do

        it 'must return a 401 status if the request is not properly authorized' do
          get "/person/id/#{@person2.id}/conversations", nil, {"HTTP_AUTHORIZATION" => "Bearer #{@person1_token}"}
          last_response.status.must_equal 401
        end

      end

    end

    describe 'get recently modified data only' do

      before do
        @mail_convo_exclude = create(:mail, correspondents: [build(:from_person, person_id: @person2.id), build(:to_person, person_id: @person1.id)])
        @mail_convo_exclude.mail_it

        @convo_exclude = @mail_convo_exclude.conversation

        @another_mail = create(:mail, correspondents: [build(:from_person, person_id: @person2.id), build(:to_person, person_id: @person3.id)])
        @another_mail.mail_it
        @another_mail.updated_at = Time.now + 5.minutes
        @another_mail.save

        @one_more_mail = create(:mail, correspondents: [build(:from_person, person_id: @person2.id), build(:to_person, person_id: @person3.id)])
        @one_more_mail.mail_it

        @an_unread_mail = create(:mail, correspondents: [build(:from_person, person_id: @person3.id), build(:to_person, person_id: @person2.id)])
        @an_unread_mail.mail_it
        @an_unread_mail.deliver

        @convo_include = @another_mail.conversation

        if_modified_since = (Time.now + 4.minutes).to_s
        get "/person/id/#{@person2.id}/conversations", nil, {"HTTP_AUTHORIZATION" => "Bearer #{@person2_token}", "HTTP_IF_MODIFIED_SINCE" => if_modified_since}
        @parsed_response = JSON.parse(last_response.body)
      end

      it 'must return a 200 status code if the conversatio metadata is fetched' do
        last_response.status.must_equal 200
      end

      it 'must only include conversations that have been modified since the date specified' do
        @parsed_response.count.must_equal 1
      end

      it 'must return the same values for the specific conversation it would have returned if no updated_at parameter had been included' do
        @parsed_response[0].must_equal JSON.parse(@convo_include.metadata_for_person(@person2).to_json)
      end

    end

  end

  describe '/person/id/:id/conversation/:conversation_id' do

    before do
      @mail1.mail_it
      @mail1.deliver
      @conversation = @mail1.conversation
    end

    describe 'get conversation' do

      before do
        get "/person/id/#{@person2.id}/conversation/id/#{@conversation.id}", nil, {"HTTP_AUTHORIZATION" => "Bearer #{@person2_token}"}
      end

      it 'must return a 200 status if the request is successful' do
        last_response.status.must_equal 200
      end

      it 'must return the expected fields for the mail' do
        response = JSON.parse(last_response.body)
        expected_result = JSON.parse(Postoffice::MailService.hash_of_mail_for_person(@mail1, @person2).to_json)
        response[0].must_equal expected_result
      end

    end

    describe 'error conditions' do

      it 'must return a 404 status if the resource is not found' do
        get "/person/id/#{@person2.id}/conversation/id/foo", nil, {"HTTP_AUTHORIZATION" => "Bearer #{@person2_token}"}
        last_response.status.must_equal 404
      end

      it 'must return a 401 status if the request is not properly authorized' do
        get "/person/id/#{@person3.id}/conversation/id/#{@conversation.id}", nil, {"HTTP_AUTHORIZATION" => "Bearer #{@person1_token}"}
        last_response.status.must_equal 401
      end

    end

  end

	describe '/mail/id/:id/read' do

		before do
			@mail1.mail_it
			@mail1.deliver
			post "/mail/id/#{@mail1.id}/read", nil, {"HTTP_AUTHORIZATION" => "Bearer #{@person2_token}"}
		end

		it 'must indicate that the person has read the mail' do
			mail = Postoffice::Mail.find(@mail1.id)
      correspondent = mail.correspondents.where(person_id: @person2.id).first
      correspondent.status.must_equal "READ"
		end

		it 'must return a 204 status code' do
			last_response.status.must_equal 204
		end

		it 'must return an empty response body' do
			last_response.body.must_equal ""
		end

		describe 'error cases' do

			it 'must return a 403 status code if mail does not have DELIVERED status' do
				post "mail/id/#{@mail2.id}/read", nil, {"HTTP_AUTHORIZATION" => "Bearer #{@person2_token}"}
				last_response.status.must_equal 403
			end

			it 'must return a 404 status code if the mail cannot be found' do
				post "mail/id/abc/read", nil, {"HTTP_AUTHORIZATION" => "Bearer #{@person2_token}"}
				last_response.status.must_equal 404
			end

		end

	end

	describe '/person/id/:id/contacts' do

		before do
			get "/person/id/#{@person1.id}/contacts", nil, {"HTTP_AUTHORIZATION" => "Bearer #{@person1_token}"}
			@response = JSON.parse(last_response.body)
		end

		it 'must return a 200 status code if the contacts are fetched successfully' do
			last_response.status.must_equal 200
		end

		it 'must include the people the person has communicated with' do
      @response.to_s.include?(@person2.id).must_equal true
		end

		it 'must return the expected information for a person record' do
			first_contact = get_person_object_from_person_response @response[0]
			@response[0].must_equal expected_json_fields_for_person(first_contact)
		end

		describe 'document not found' do

			it 'must return a 404 status code' do
				get '/person/id/abc123/contacts', nil, {"HTTP_AUTHORIZATION" => "Bearer #{@admin_token}"}
				last_response.status.must_equal 404
			end

		end

	end

	describe '/people/search' do

		before do

			@rando_name = random_username

			@person5 = create(:person, given_name: @rando_name, username: random_username)
			@person6 = create(:person, given_name: @rando_name, username: random_username)
			@person7 = create(:person, given_name: @rando_name, username: random_username)

			get "/people/search?term=#{@rando_name}&limit=2", nil, {"HTTP_AUTHORIZATION" => "Bearer #{@person1_token}"}
			@response = JSON.parse(last_response.body)

		end

		it 'must return a 200 status code' do
			last_response.status.must_equal 200
		end

		it 'must limit the number of records returned based on the limit parameter' do
			assert_operator @response.count, :<=, 2
		end

		it 'must return the expected information for a person record' do
			first_result = get_person_object_from_person_response @response[0]
			@response[0].must_equal expected_json_fields_for_person(first_result)
		end

	end

  describe '/people/find_matches' do
    before do
      @personA = create(:person, username: random_username, email: "person1@google.com")
			@personB = create(:person, username: random_username, email: "person2@google.com")
			@personC = create(:person, username: random_username, email: "person3@google.com")
			@personD = create(:person, username: random_username, email: "person4@google.com")

      data = '{"emails": ["person1@google.com", "person2@google.com", "person@yahoo.com", "person@hotmail.com", "person4@google.com"]}'

			post "/people/find_matches", data, {"HTTP_AUTHORIZATION" => "Bearer #{@person1_token}"}

      @parsed_response = JSON.parse(last_response.body)
    end

    it 'must return a 201 status code if matches are found' do
      last_response.status.must_equal 201
    end

    it 'must return a JSON document with the relevant people records for people with matching emails' do
      @parsed_response.to_s.include?("person1@google.com").must_equal true
    end

    it 'must return all of the matching records' do
      @parsed_response.count.must_equal 3
    end

    it 'must return the expected fields for a person' do
      first_result = get_person_object_from_person_response @parsed_response[0]
      @parsed_response[0].must_equal expected_json_fields_for_person(first_result)
    end

  end

  describe '/upload' do

    describe 'upload a file' do

      before do
        image_file = File.open('spec/resources/image1.jpg')
        @filename = 'image1.jpg'
        @image_file_size = File.size(image_file)
        base64_string = Base64.encode64(image_file.read)
        data = '{"file": "' + base64_string + '", "filename": "image1.jpg"}'
        post "/upload", data, {"HTTP_AUTHORIZATION" => "Bearer #{@person1_token}"}
        image_file.close
      end

      it 'must return a 201 status code if a file is successfuly uploaded' do
        last_response.status.must_equal 201
      end

      it 'must return an empty response body' do
        last_response.body.must_equal ""
      end

      it 'must include the uid in the header' do
        last_response.headers["location"].must_be_instance_of String
      end

      it 'must upload the object to the AWS S3 store' do
        uid = last_response.headers["location"]
        Dragonfly.app.fetch(uid).name.must_equal @filename
      end

      it 'must upload the complete contents of the file as the AWS object' do
        uid = last_response.headers["location"]
        Dragonfly.app.fetch(uid).size.must_equal @image_file_size
      end

    end

  end

  describe 'get a list of cards available' do

    before do
      get "/cards", nil, {"HTTP_AUTHORIZATION" => "Bearer #{@person1_token}"}
    end

    it 'must return a 200 status' do
      last_response.status.must_equal 200
    end

    it 'must include an array of cards in the response' do
      cards = JSON.parse(last_response.body)
      cards.must_be_instance_of Array
    end

  end

  describe 'get image by its uid' do

    describe 'get an image' do

      before do
        get "/image/resources/cards/Dhow.jpg", nil, {"HTTP_AUTHORIZATION" => "Bearer #{@person1_token}"}
      end

      it 'must redirect and return a 302 status' do
        last_response.status.must_equal 302
      end

    end

    describe 'get an image that is not in the resources directory' do

      before do
        image = File.open('spec/resources/image2.jpg')
        @uid = Dragonfly.app.store(image.read, 'name' => 'image2.jpg')
      end

      it 'must succeed if the token has can-read scope' do
        get "/image/#{@uid}", nil, {"HTTP_AUTHORIZATION" => "Bearer #{@person1_token}"}
        last_response.status.must_equal 302
      end

    end

  end

end
