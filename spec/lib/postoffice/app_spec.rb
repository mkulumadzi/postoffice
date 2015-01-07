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
			@data = '{"username":"kasabian", "name":"Kasabian"}'
		end

		it 'must return a 201 status code' do
			post '/person/new', @data	
			last_response.status.must_equal 201
		end

		it 'must return an empty body' do
			post '/person/new', @data
			last_response.body.must_equal ""
		end

		it 'must include a link to the person in the header' do
			post '/person/new', @data
			assert_match(/http:\/\/localhost\:9292\/person\/id\/\w{24}/, last_response.header["location"])
		end

	end

end

describe '/person/id/:id' do

	describe 'get /person/id/:id' do

		before do
			data = '{"username":"kasabian", "name":"Kasabian"}'
			post '/person/new', data
			@location = last_response.headers["location"]
			@id = @location.split('/')[-1]
		end

		it 'must return a 200 status code' do
			get "/person/id/#{@id}"
			last_response.status.must_equal 200
		end

		# To do: improve this test...
		it 'must return a JSON document for the person in the response body' do
			get "/person/id/#{@id}"
			last_response.body.must_include "Kasabian"
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
