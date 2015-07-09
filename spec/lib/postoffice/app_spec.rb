require 'rack/test'
require 'minitest/autorun'
require_relative '../../spec_helper'

include Rack::Test::Methods

def app
  Sinatra::Application
end

describe app do

# Set up data for testing
	let ( :person1 ) {
		data = JSON.parse '{"username": "' + SnailMail::Person.random_username + '", "name":"Evan", "password": "password", "device_token": "abc123"}'
		SnailMail::PersonService.create_person data
	}

	let ( :person2 ) {
		data = JSON.parse '{"username": "' + SnailMail::Person.random_username + '", "name":"Neal", "password": "password"}'
		SnailMail::PersonService.create_person data
	}

	let ( :person3 ) {
		data = JSON.parse '{"username": "' + SnailMail::Person.random_username + '", "name":"Kasabian", "password": "password"}'
		SnailMail::PersonService.create_person data
	}

	let ( :mail1 ) {
		SnailMail::Mail.create!(
			from: "#{person1.username}",
			to: "#{person2.username}",
			content: "What up",
			image: "SnailMail at the Beach.png"
		)	
	}

	let ( :mail2 ) {
		SnailMail::Mail.create!(
			from: "#{person1.username}",
			to: "#{person2.username}",
			content: "Hey",
			image: "Default Card.png"
		)	
	}

	let ( :mail_data ) {
		'{"to": "' + person2.username + '", "content": "Hey"}'
	}

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

	describe '/person/new' do

		describe 'post /person/new' do

			before do
				@username = SnailMail::Person.random_username
				data = '{"username": "' + @username + '", "name":"Kasabian", "password": "password"}'
				post '/person/new', data
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

			it 'must return a 403 error if a duplicate username is posted' do
				data = '{"username": "' + @username + '", "name":"Kasabian"}'
				post '/person/new', data
				last_response.status.must_equal 403
			end

			describe 'generate welcome message' do

				before do
					mailArray = []
					SnailMail::Mail.where(to: @username).each do |mail|
						mailArray << mail
					end
					@mail = mailArray[0]
				end

				it 'must generate a welcome message from the SnailMail Postman' do
					@mail.from.must_equal "snailmail.kuyenda@gmail.com"
				end

				it 'must set the image to be the SnailMail Postman' do
					@mail.image.must_equal "SnailMail Postman.png"
				end

				it 'must deliver the mail' do
					assert_operator @mail.scheduled_to_arrive, :<=, Time.now
				end

				it 'must include standard welcome text in the mail content' do
					text = File.open("templates/Welcome Message.txt").read
					@mail.content.must_equal text
				end

			end

		end

	end

	describe '/person/id/:id' do

		describe 'get /person/id/:id' do

			it 'must return a 200 status code' do
				get "/person/id/#{person1.id}"
				last_response.status.must_equal 200
			end

			it 'must return a JSON document as a hash in the response body with the username' do
				get "/person/id/#{person1.id}"
				last_response.body.must_include person1.username
			end

			it 'must not return the salt' do
				get "/person/id/#{person1.id}"
				response = JSON.parse(last_response.body)
				response["salt"].must_equal nil
			end

			it 'must not return the hashed password' do
				get "/person/id/#{person1.id}"
				response = JSON.parse(last_response.body)
				response["hashed_password"].must_equal nil
			end

			it 'must not return the device token' do
				get "person/id/#{person1.id}"
				response = JSON.parse(last_response.body)
				response["device_token"].must_equal nil
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
				post "person/id/#{person1.id}", data
			end

			it 'must return a 204 status code' do
				last_response.status.must_equal 204
			end

			it 'must update the person record' do
				person = SnailMail::Person.find(person1.id)
				person.city.must_equal "New York"
			end

			it 'must not void fields that are not included in the update' do
				person = SnailMail::Person.find(person1.id)
				person.name.must_equal "Evan"
			end

		end

		describe 'prevent invalid updates' do

			it 'must raise a 403 error if the username is attempted to be updated' do
				data = '{"username": "new_username"}'
				post "person/id/#{person1.id}", data
				last_response.status.must_equal 403
			end

		end

	end

	describe '/login' do

		describe 'successful login' do

			before do
				data = '{"username": "' + person3.username + '", "password": "password"}'
				post "/login", data
			end

			it 'must return a 200 status code for a successful login' do
				last_response.status.must_equal 200
			end

		end

		describe 'incorrect password' do

			before do
				data = '{"username": "' + person3.username + '", "password": "wrong_password"}'
				post "/login", data
			end

			it 'must return a 401 status code for an incorrect password' do
				last_response.status.must_equal 401
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

		it 'must not return the salt for any of the records' do
			get '/people'
			collection = JSON.parse(last_response.body)
			i = 0
			collection.each do |record|
				if record["salt"] != nil
					i += 1
				end
			end
			i.must_equal 0
		end

		it 'must not return the hashed_password for any of the records' do
			get '/people'
			collection = JSON.parse(last_response.body)
			i = 0
			collection.each do |record|
				if record["hashed_password"] != nil
					i += 1
				end
			end
			i.must_equal 0
		end

		it 'must not return the device token for any of the records' do
			get '/people'
			collection = JSON.parse(last_response.body)
			i = 0
			collection.each do |record|
				if record["device_token"] != nil
					i += 1
				end
			end
			i.must_equal 0
		end

		it 'must return a filtered collection if parameters are given' do
			get "/people?name=Evan"
			expected_number = SnailMail::Person.where(name: "Evan").count
			actual_number = JSON.parse(last_response.body).count
			actual_number.must_equal expected_number
		end

	end

	describe '/person/id/:id/mail/new' do

		describe 'post /person/id/:id/mail/new' do

			before do
				post "/person/id/#{person1.id}/mail/new", mail_data
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
				post "/person/id/#{from_id}/mail/new", mail_data
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

		describe 'post /person/id/:id/mail/send' do

			before do
				post "/person/id/#{person1.id}/mail/send", mail_data
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
				get "/mail/id/#{mail1.id}"
				last_response.status.must_equal 200
			end

			# To do: improve this test...
			it 'must return a JSON document for the mail in the response body' do
				get "/mail/id/#{mail1.id}"
				last_response.body.must_include "What up"
			end

			it 'must update the delivery status of the mail' do
				mail1.mail_it
				mail1.deliver_now
				get "/mail/id/#{mail1.id}"
				SnailMail::Mail.find(mail1.id).status.must_equal "DELIVERED"
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
				post "/mail/id/#{mail1.id}/send"
			end

			it 'must send the mail' do
				mail = SnailMail::Mail.find(mail1.id)
				mail.status.must_equal "SENT"
			end

			it 'must be scheduled to arrive' do
				mail = SnailMail::Mail.find(mail1.id)			
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
					post "/mail/id/#{mail1.id}/send"
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
				post "/mail/id/#{mail1.id}/send"
				post "/mail/id/#{mail1.id}/deliver"
			end

			it 'must be scheduled to arrive in the past' do
				mail = SnailMail::Mail.find(mail1.id)			
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
				post "/mail/id/#{mail1.id}/deliver"
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
			mail1
			get '/mail'
			last_response.body.must_include "_id"
		end

		it 'must return a filtered collection if parameters are given' do
			mail1
			get "/mail?from=#{person1.username}"
			last_response.body.must_include "_id"
		end

	end

	describe '/person/id/:id/mailbox' do

		before do

			mail1.mail_it

			# Put the arrival date safely in the past
			# To do: implement a "deliver now" feature that could be used for these tests
			mail1.scheduled_to_arrive = mail1.scheduled_to_arrive - 6 * 86400
			mail1.save

			mail2.mail_it
			mail2.save

		end

		it 'must return a collection of mail that has arrived' do
			get "/person/id/#{person2.id}/mailbox"
			last_response.body.must_include mail1.id
		end

		it 'must not return any mail that has not yet arrived' do
			get "/person/id/#{person2.id}/mailbox"
			last_response.body.match(/#{mail2.id}/).must_equal nil
		end

	end

	describe '/person/id/:id/outbox' do

		before do
			mail1.mail_it
		end

		it 'must return a collection of mail that has been sent by the user' do
			get "/person/id/#{person1.id}/outbox"
			last_response.body.must_include mail1.id
		end

		it 'must not include mail that was sent by someone else' do
			get "/person/id/#{person2.id}/outbox"
			last_response.body.match(/#{mail1.id}/).must_equal nil
		end

	end

	describe '/mail/id/:id/read' do

		before do
			mail1.mail_it
			mail1.deliver_now
			mail1.update_delivery_status

			post "/mail/id/#{mail1.id}/read"
		end

		it 'must mark the mail as read' do
			mail = SnailMail::Mail.find(mail1.id)
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
				post "mail/id/#{mail2.id}/read"
				last_response.status.must_equal 403
			end

			it 'must return a 404 status code if the mail cannot be found' do
				post "mail/id/abc/read"
				last_response.status.must_equal 404
			end

		end

	end

end
