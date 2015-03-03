require 'rack/test'
require 'minitest/autorun'
require_relative '../../spec_helper'

include Rack::Test::Methods

def app
  Sinatra::Application
end

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
			username = SnailMail::Person.random_username
			data = '{"username": "' + username + '", "name":"Kasabian"}'
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

	end

end

describe '/person/id/:id' do

	describe 'get /person/id/:id' do

		before do
			@username = SnailMail::Person.random_username
			data = '{"username": "' + @username + '", "name":"Kasabian"}'
			post '/person/new', data
			@location = last_response.headers["location"]
			@id = @location.split('/')[-1]
		end

		it 'must return a 200 status code' do
			get "/person/id/#{@id}"
			last_response.status.must_equal 200
		end

		# To do: improve this test...
		it 'must return a JSON document as a hash in the response body with the username' do
			get "/person/id/#{@id}"
			last_response.body.must_include @username
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
			@person1 = SnailMail::Person.create!(
				name: "Evan",
				username: SnailMail::Person.random_username
			)

			@person2 = SnailMail::Person.create!(
				name: "Neal",
				username: SnailMail::Person.random_username
			)

			data = '{"to": "' + @person2.username + '", "content": "Hey"}'
			post "/person/id/#{@person1.id}/mail/new", data
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

		it 'must use the days_to_arrive_method to generate a random number of days for the mail' do
			mail_location = last_response.headers["location"]
			mail_id = mail_location.split('/')[-1]
			mail = SnailMail::Mail.find(mail_id)
			range = (3..5).to_a
			range.include?(mail.days_to_arrive).must_equal true
		end

	end

	describe 'post mail for a person that does not exist' do

		before do
			from_id = 'abc'

			@person2 = SnailMail::Person.create!(
				name: "Neal",
				username: SnailMail::Person.random_username
			)

			data = '{"to": "' + @person2.username + '", "content": "Hey"}'
			post "/person/id/#{from_id}/mail/new", data
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

		before do

			@person1 = SnailMail::Person.create!(
				name: "Evan",
				username: SnailMail::Person.random_username
			)

			@person2 = SnailMail::Person.create!(
				name: "Neal",
				username: SnailMail::Person.random_username
			)

			data = '{"to": "' + @person2.username + '", "content": "Hey"}'
			post "/person/id/#{@person1.id}/mail/new", data

			mail_location = last_response.headers["location"]
			@mail_id = mail_location.split('/')[-1]

		end

		it 'must return a 200 status code' do
			get "/mail/id/#{@mail_id}"
			last_response.status.must_equal 200
		end

		# To do: improve this test...
		it 'must return a JSON document for the mail in the response body' do
			get "/mail/id/#{@mail_id}"
			last_response.body.must_include "Hey"
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
		get '/mail'
		last_response.body.must_include "_id"
	end

	it 'must return a filtered collection if parameters are given' do

		@person1 = SnailMail::Person.create!(
			name: "Evan",
			username: SnailMail::Person.random_username
		)

		@person2 = SnailMail::Person.create!(
			name: "Neal",
			username: SnailMail::Person.random_username
		)

		data = '{"to": "' + @person2.username + '", "content": "Hey"}'
		post "/person/id/#{@person1.id}/mail/new", data

		get "/mail?from=#{@person1.username}"
		last_response.body.must_include "_id"
	end

end
