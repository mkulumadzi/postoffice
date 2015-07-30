require 'rack/test'
require 'minitest/autorun'
require_relative '../../spec_helper'
require "base64"

include Rack::Test::Methods

def app
  Sinatra::Application
end

describe app do

	before do

		@person1 = create(:person, username: random_username)
		@person2 = create(:person, username: random_username)
		@person3 = create(:person, username: random_username)

		@mail1 = create(:mail, from: @person1.username, to: @person2.username)
		@mail2 = create(:mail, from: @person1.username, to: @person2.username)
		@mail3 = create(:mail, from: @person3.username, to: @person1.username)

		@mail4 = build(:mail, from: @person1.username, to: @person2.username)

	end

	describe 'app_root' do

		describe 'get /' do
			it 'must say hello world' do
				get '/'
				last_response.body.must_include "Hello World"
			end
		end

		describe 'SNAILMAIL_BASE_URL' do
			it 'must have a value for SNAILMAIL BASE URL' do
				ENV['SNAILMAIL_BASE_URL'].must_be_instance_of String
			end
		end
	end

	describe 'post /person/new' do

		before do
			@username = random_username
			data = '{"username": "' + @username + '", "phone": "' + random_phone + '", "email": "' + random_email + '", "password": "password"}'
			post "/person/new", data
		end

		it 'must return a 201 status code' do
			last_response.status.must_equal 201
		end

		it 'must return an empty body' do
			last_response.body.must_equal ""
		end

		it 'must include a link to the person in the header' do
			assert_match(/#{ENV['SNAILMAIL_BASE_URL']}\/person\/id\/\w{24}/, last_response.header["location"])
		end

		describe 'welcome message' do

			before do
				@welcome_mail = SnailMail::Mail.find_by(to: @username)
			end

			it 'must generate a welcome message from the SnailMail Postman' do
				@welcome_mail.from.must_equal "snailmail.kuyenda"
			end

			it 'must set the image to be the SnailMail Postman' do
				@welcome_mail.image.must_equal "SnailMail Postman.png"
			end

			it 'must deliver the mail' do
				assert_operator @welcome_mail.scheduled_to_arrive, :<=, Time.now
			end

			it 'must include standard welcome text in the mail content' do
				text = File.open("templates/Welcome Message.txt").read
				@welcome_mail.content.must_equal text
			end

		end

		describe 'duplicate username' do

			before do
				data = '{"username": "' + @person1.username + '", "phone": "' + random_phone + '", "email": "' + random_email + '", "password": "password"}'
				post "/person/new", data
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
				post "/person/new", data
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
				post "/person/new", data
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
				post "/person/new", data
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
				post "/person/new", data
			end

			it 'must return a 403 error if no email is posted' do
				last_response.status.must_equal 403
			end

			it 'must return the correct error message' do
				response = JSON.parse(last_response.body)
				response["message"].must_equal "Missing required field: email"
			end

		end

		describe 'no phone number' do

			before do
				data = '{"username": "' + random_username + '", "email": "' + random_email + '", "password": "password"}'
				post "/person/new", data
			end

			it 'must return a 403 error if no phone is posted' do
				last_response.status.must_equal 403
			end

			it 'must return the correct error message' do
				response = JSON.parse(last_response.body)
				response["message"].must_equal "Missing required field: phone"
			end

		end

		describe 'no password' do

			before do
				data = '{"username": "' + random_username + '", "email": "' + random_email + '", "phone": "' + random_phone + '", "password": ""}'
				post "/person/new", data
			end

			it 'must return a 403 error if no password is posted' do
				last_response.status.must_equal 403
			end

			it 'must return the correct error message' do
				response = JSON.parse(last_response.body)
				response["message"].must_equal "Missing required field: password"
			end

		end

	end

	describe '/person/id/:id' do

		describe 'get /person/id/:id' do

			before do
				get "/person/id/#{@person1.id}"
				@response = JSON.parse(last_response.body)
			end

			it 'must return a 200 status code' do
				last_response.status.must_equal 200
			end

			it 'must return the expected fields' do
				@response.must_equal expected_json_fields_for_person(@person1)
			end

		end

		describe 'resource not found' do

			before do
				get "person/id/abc"
			end

			it 'must return 404 if the person is not found' do
				last_response.status.must_equal 404
			end

			it 'must return an empty response body if the person is not found' do
				last_response.body.must_equal ""
			end

		end

		describe 'post /person/id/:id' do

			before do
				data = '{"city": "New York", "state": "NY"}'
				post "person/id/#{@person1.id}", data
			end

			it 'must return a 204 status code' do
				last_response.status.must_equal 204
			end

			it 'must update the person record' do
				person = SnailMail::Person.find(@person1.id)
				person.city.must_equal "New York"
			end

			it 'must not void fields that are not included in the update' do
				person = SnailMail::Person.find(@person1.id)
				person.name.must_equal @person1.name
			end

		end

		describe 'prevent invalid updates' do

			it 'must raise a 403 error if the username is attempted to be updated' do
				data = '{"username": "new_username"}'
				post "person/id/#{@person1.id}", data
				last_response.status.must_equal 403
			end

		end

	end

	describe '/login' do

		describe 'successful login' do

			before do

				# Creating a person with a password to test login
				person_attrs = attributes_for(:person)
				data = Hash["username", random_username, "name", person_attrs[:name], "email", random_email, "phone", random_phone, "password", "password"]
				@user = SnailMail::PersonService.create_person data

				data = '{"username": "' + @user.username + '", "password": "password"}'
				post "/login", data
				@person_json = JSON.parse(last_response.body)
			end

			it 'must return a 200 status code' do
				last_response.status.must_equal 200
			end

			it 'must include the person id in the response body' do
				BSON::ObjectId.from_string(@person_json["_id"]["$oid"]).must_equal @user.id
			end

			it 'must include the username in the response body' do
				@person_json["username"].must_equal @user.username
			end

			it 'must include the name in the response body' do
				@person_json["name"].must_equal @user.name
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

	describe '/person/id/:id/reset_password' do

		before do
			person_attrs = attributes_for(:person)
			data = Hash["username", random_username, "name", person_attrs[:name], "email", random_email, "phone", random_phone, "password", "password"]
			@person = SnailMail::PersonService.create_person data
		end

		describe 'submit the correct old password and a valid new password' do

			before do
				data = '{"old_password": "password", "new_password": "password123"}'
				post "/person/id/#{@person.id.to_s}/reset_password", data
			end

			it 'must return a 204 status code' do
				last_response.status.must_equal 204
			end

			it 'must reset the password' do
				person_record = SnailMail::Person.find(@person.id)
				person_record.hashed_password.must_equal SnailMail::LoginService.hash_password "password123", person_record.salt
			end

			it 'must return an empty response body' do
				last_response.body.must_equal ""
			end

		end

		describe 'error conditions' do

			it 'must return a 404 error if the person record cannot be found' do
				data = '{"old_password": "password", "new_password": "password123"}'
				post "/person/id/abc123/reset_password", data

				last_response.status.must_equal 404
			end

			describe 'Runtime errors' do

				before do
					#Example case: Submit wrong password
					data = '{"old_password": "wrongpassword", "new_password": "password123"}'
					post "/person/id/#{@person.id.to_s}/reset_password", data
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

	end

	describe '/people' do

		it 'must return a 200 status code' do
			get '/people'
			last_response.status.must_equal 200
		end

		it 'must return a collection with all of the people if no parameters are entered' do
			get '/people'
			collection = JSON.parse(last_response.body)
			num_people = SnailMail::Person.count
			collection.length.must_equal num_people
		end

		it 'must return a filtered collection if parameters are given' do
			get "/people?name=Evan"
			expected_number = SnailMail::Person.where(name: "Evan").count
			actual_number = JSON.parse(last_response.body).count
			actual_number.must_equal expected_number
		end

		it 'must return the expected information for a person record' do
			get "/people?id=#{@person1.id}"
			people_response = JSON.parse(last_response.body)

			people_response[0].must_equal expected_json_fields_for_person(@person1)
		end

	end

	describe '/person/id/:id/mail/new' do

		before do
			@mail_data = convert_mail_to_json @mail4
		end

		describe 'post /person/id/:id/mail/new' do

			before do
				post "/person/id/#{@person1.id}/mail/new", @mail_data
			end

			it 'must get a status of 201' do
				last_response.status.must_equal 201
			end

			it 'must return an empty body' do
				last_response.body.must_equal ""
			end

			it 'must include a link to the mail in the header' do
				assert_match(/#{ENV['SNAILMAIL_BASE_URL']}\/mail\/id\/\w{24}/, last_response.header["location"])
			end

		end

		describe 'post mail for a person that does not exist' do

			before do
				from_id = 'abc'
				post "/person/id/#{from_id}/mail/new", @mail_data
			end

			it 'should return a 404 status' do
				last_response.status.must_equal 404
			end

			it 'should return an empty response body' do
				last_response.body.must_equal ""
			end

		end

	end

	describe '/person/id/:id/mail/send' do

		before do
			@mail_data = convert_mail_to_json @mail4
		end

		describe 'post /person/id/:id/mail/send' do

			before do
				post "/person/id/#{@person1.id}/mail/send", @mail_data
			end

			it 'must get a status of 201' do
				last_response.status.must_equal 201
			end

			it 'must return an empty body' do
				last_response.body.must_equal ""
			end

			it 'must include a link to the mail in the header' do
				assert_match(/#{ENV['SNAILMAIL_BASE_URL']}\/mail\/id\/\w{24}/, last_response.header["location"])
			end

			it 'must have sent the mail' do
				mail_id = last_response.header["location"].split("/").pop
				mail = SnailMail::Mail.find(mail_id)
				mail.status.must_equal "SENT"
			end

		end

	end

	describe '/mail/id/:id' do

		describe 'get /mail/id/:id' do

			it 'must return a 200 status code' do
				get "/mail/id/#{@mail1.id}"
				last_response.status.must_equal 200
			end

			it 'must return the expected JSON document for the mail in the response body' do
				get "/mail/id/#{@mail1.id}"
				response = JSON.parse(last_response.body)
				response.must_equal expected_json_fields_for_mail(@mail1)
			end

		end

		describe 'resource not found' do

			before do
				get "mail/id/abc"
			end

			it 'must return 404 if the mail is not found' do
				last_response.status.must_equal 404
			end

			it 'must return an empty response body if the mail is not found' do
				last_response.body.must_equal ""
			end

		end

		describe 'post /mail/id/:id/send' do

			before do
				post "/mail/id/#{@mail1.id}/send"
			end

			it 'must send the mail' do
				mail = SnailMail::Mail.find(@mail1.id)
				mail.status.must_equal "SENT"
			end

			it 'must be scheduled to arrive' do
				mail = SnailMail::Mail.find(@mail1.id)
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
					post "/mail/id/#{@mail1.id}/send"
				end

				it 'must return a 403 status' do
					last_response.status.must_equal 403
				end

				it 'must return an empty response body' do
					last_response.body.must_equal ""
				end

			end

		end

		describe 'send to a missing piece of mail' do

			before do
				post "/mail/id/abc/send"
			end

			it 'must return 404 if the mail is not found' do
				last_response.status.must_equal 404
			end

			it 'must return an empty response body' do
				last_response.body.must_equal ""
			end

		end

		describe 'post /mail/id/:id/deliver' do

			before do
				post "/mail/id/#{@mail1.id}/send"
				post "/mail/id/#{@mail1.id}/deliver"
			end

			it 'must be scheduled to arrive in the past' do
				mail = SnailMail::Mail.find(@mail1.id)
				assert_operator mail.scheduled_to_arrive, :<=, Time.now
			end

			it 'must return a 204 status code' do
				last_response.status.must_equal 204
			end

			it 'must return an empty response body' do
				last_response.body.must_equal ""
			end

		end

		describe 'try to deliver mail that has not been sent' do

			before do
				post "/mail/id/#{@mail1.id}/deliver"
			end

			it 'must return a 403 status' do
				last_response.status.must_equal 403
			end

			it 'must return empty response body' do
				last_response.body.must_equal ""
			end

		end

		describe 'send to a missing piece of mail' do

			before do
				post "/mail/id/abc/deliver"
			end

			it 'must return 404 if the mail is not found' do
				last_response.status.must_equal 404
			end

			it 'must return an empty response body' do
				last_response.body.must_equal ""
			end

		end

	end

	describe '/mail' do

		it 'must return a 200 status code' do
			get '/mail'
			last_response.status.must_equal 200
		end

		it 'must return a collection with all of the mail if no parameters are entered' do
			get '/mail'
			response = JSON.parse(last_response.body)
			response.count.must_equal SnailMail::Mail.count
		end

		it 'must return a filtered collection if parameters are given' do
			get "/mail?from=#{@person1.username}"
			response = JSON.parse(last_response.body)
			response.count.must_equal SnailMail::Mail.where(from: @person1.username).count
		end

		it 'must return the expected fields for the mail' do
			get "/mail?id=#{@mail1.id}"
			response = JSON.parse(last_response.body)
			response[0].must_equal expected_json_fields_for_mail(@mail1)
		end

	end

	describe '/person/id/:id/mailbox' do

		before do

			@mail1.mail_it
			@mail1.deliver_now
			@mail1.save

			@mail2.mail_it
			@mail2.save

		end

		it 'must return a collection of mail that has arrived' do
			get "/person/id/#{@person2.id}/mailbox"
			last_response.body.must_include @mail1.id
		end

		it 'must not return any mail that has not yet arrived' do
			get "/person/id/#{@person2.id}/mailbox"
			last_response.body.match(/#{@mail2.id}/).must_equal nil
		end

		it 'must return the expected fields for the mail' do
			get "/person/id/#{@person2.id}/mailbox"
			response = JSON.parse(last_response.body)
			mail = get_mail_object_from_mail_response response[0]

			response[0].must_equal expected_json_fields_for_mail(mail)
		end

	end

	describe '/person/id/:id/outbox' do

		before do
			@mail1.mail_it
		end

		it 'must return a collection of mail that has been sent by the user' do
			get "/person/id/#{@person1.id}/outbox"
			last_response.body.must_include @mail1.id
		end

		it 'must not include mail that was sent by someone else' do
			get "/person/id/#{@person2.id}/outbox"
			last_response.body.match(/#{@mail1.id}/).must_equal nil
		end

		it 'must return the expected fields for the mail' do
			get "/person/id/#{@person1.id}/outbox"
			response = JSON.parse(last_response.body)
			mail = get_mail_object_from_mail_response response[0]

			response[0].must_equal expected_json_fields_for_mail(mail)
		end

	end

	describe '/mail/id/:id/read' do

		before do
			@mail1.mail_it
			@mail1.deliver_now
			@mail1.update_delivery_status

			post "/mail/id/#{@mail1.id}/read"
		end

		it 'must mark the mail as read' do
			mail = SnailMail::Mail.find(@mail1.id)
			mail.status.must_equal "READ"
		end


		it 'must return a 204 status code' do
			last_response.status.must_equal 204
		end

		it 'must return an empty response body' do
			last_response.body.must_equal ""
		end

		describe 'error cases' do

			it 'must return a 403 status code if mail does not have DELIVERED status' do
				post "mail/id/#{@mail2.id}/read"
				last_response.status.must_equal 403
			end

			it 'must return a 404 status code if the mail cannot be found' do
				post "mail/id/abc/read"
				last_response.status.must_equal 404
			end

		end

	end

	describe '/person/id/:id/contacts' do

		before do
			get "/person/id/#{@person1.id}/contacts"
			@response = JSON.parse(last_response.body)
		end

		it 'must return a 200 status code' do
			last_response.status.must_equal 200
		end

		## This test should be improved...
		it 'must return all of the users contacts' do
			contacts = SnailMail::MailService.get_contacts @person1.username
			@response.length.must_equal contacts.length
		end

		it 'must return the expected information for a person record' do
			first_contact = get_person_object_from_person_response @response[0]
			@response[0].must_equal expected_json_fields_for_person(first_contact)
		end

		describe 'document not found' do

			it 'must return a 404 status code' do
				get '/person/id/abc123/contacts'
				last_response.status.must_equal 404
			end

		end

	end

	describe '/people/search' do

		before do

			@rando_name = random_username

			@person5 = create(:person, name: @rando_name, username: random_username)
			@person6 = create(:person, name: @rando_name, username: random_username)
			@person7 = create(:person, name: @rando_name, username: random_username)

			get "/people/search?term=#{@rando_name}&limit=2"
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

	describe '/people/bulk_search' do

		before do

			@rando_name = random_username

			@person5 = create(:person, name: @rando_name, username: random_username)
			@person6 = create(:person, name: @rando_name, username: random_username)

			data = '[{"emails": ["'+ @person5.email + '"], "phoneNumbers": ["' + @person5.phone + '"]}, {"emails": ["' + @person6.email + '"], "phoneNumbers": []}, {"emails": [], "phoneNumbers": ["55667"]}]'

			post "/people/bulk_search", data

			@response = JSON.parse(last_response.body)
		end

		it 'must generate a 200 status code' do
			last_response.status.must_equal 200
		end

		it 'must return a JSON document with the relevant people records' do
			not_in = 0
			expected_ids = [@person5.id, @person6.id]

			expected_ids.each do |id|
				if @response.include? id == false
					not_in += 1
				end
			end

			not_in.must_equal 0
		end

		it 'must return the expected information for a person record' do
			first_result = get_person_object_from_person_response @response[0]
			@response[0].must_equal expected_json_fields_for_person(first_result)
		end

	end

  describe '/upload' do

    describe 'upload a file' do

      before do
          @file = File.open("resources/asamplefile.txt")
          @filestring = Base64.encode64(@file.read)
          # post "/upload", "file" => @file.read, "filename" => "image2.jpg"

          data = '{"file": "' + @filestring + '", "filename": "asamplefile.txt"}'
          post "/upload", data
          @file.close
      end

      it 'must return a 201 status code if a file is successfuly updated' do
        last_response.status.must_equal 201
      end

      it 'must return an empty response body' do
        last_response.body.must_equal ""
      end

      it 'must include the key in the header' do
        last_response.headers["location"].must_be_instance_of String
      end

      it 'must upload the object to the AWS S3 store' do
        obj = SnailMail::FileService.get_object_for_key last_response.headers["location"]
        obj.exists?.must_equal true
      end

      it 'must upload the complete contents of the file as the AWS object' do
        obj = SnailMail::FileService.get_object_for_key last_response.headers["location"]
        obj.content_length.must_equal File.size(@file)
      end

      describe 'missing filename' do

        before do
          @file = File.open("resources/asamplefile.txt")
          @filestring = Base64.encode64(@file.read)
          # post "/upload", "file" => @file.read, "filename" => nil

          data = '{"file": "' + @filestring + '"}'
          post "/upload", data
          @response = last_response
          @file.close
        end

        it 'must return a 403 status code' do
          @response.status.must_equal 403
        end

        it 'must include an error message in the response body' do
          message = JSON.parse(@response.body)["message"]
          message.must_equal "Filename must be included in request"
        end

      end

    end

  end

end
