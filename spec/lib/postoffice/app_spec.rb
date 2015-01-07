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

	

end
