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
		SnailMail::Person.create!(
			name: "Evan",
			username: SnailMail::Person.random_username
		)
	}

	let ( :person2 ) {
		SnailMail::Person.create!(
			name: "Neal",
			username: SnailMail::Person.random_username
		)
	}

	let ( :mail1 ) {
		SnailMail::Mail.create!(
			from: "#{person1.username}",
			to: "#{person2.username}",
			content: "What up"
		)	
	}

	let ( :mail2 ) {
		SnailMail::Mail.create!(
			from: "#{person1.username}",
			to: "#{person2.username}",
			content: "Hey"
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
	end

	describe '/person/new' do

		describe 'post /person/new' do

			before do
				@username = SnailMail::Person.random_username
				data = '{"username": "' + @username + '", "name":"Kasabian"}'
				post '/person/new', data
			end

			it 'must return a 201 status code' do	
				last_response.status.must_equal 201
			end

			it 'must return an empty body' do
				last_response.body.must_equal ""
			end

			it 'must include a link to the person in the header' do
				assert_match(/http:\/\/localhost\:9292\/person\/id\/\w{24}/, last_response.header["location"])
			end

			it 'must return a 403 error if a duplicate username is posted' do
				data = '{"username": "' + @username + '", "name":"Kasabian"}'
				post '/person/new', data
				last_response.status.must_equal 403
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

	end

	describe '/people' do

		it 'must return a 200 status code' do
			get '/people'
			last_response.status.must_equal 200
		end

		# To do: improve these tests...
		# It kind of duplicates the test for People.find_all - maybe just test that this method is called?
		it 'must return a collection with all of the people if no paremters are entered' do
			get '/people'
			last_response.body.must_include "_id"
		end

		it 'must return a filtered collection if parameters are given' do
			username = SnailMail::Person.random_username
			data = '{"username": "' + username + '", "name":"Kasabian"}'
			post '/person/new', data
			get "/people?username=#{username}"
			last_response.body.must_include "_id"
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
				assert_match(/http:\/\/localhost\:9292\/mail\/id\/\w{24}/, last_response.header["location"])
			end

			## Handle this later with a separate route.
			# it 'must send the mail' do
			# 	mail_location = last_response.headers["location"]
			# 	mail_id = mail_location.split('/')[-1]
			# 	mail = SnailMail::Mail.find(mail_id)

			# 	mail.status.must_equal "SENT"
			# end

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

	describe '/person/id/:id/inbox' do

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
end
