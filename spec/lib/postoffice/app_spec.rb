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
			@data = JSON.prase("{'username':'ewaters'}")
		end

		it 'must process the json body as parameters' do
			post ('/person/new', @data)
			json_parse(last_response.body).must_equal "Foo"
		end

	end

end

describe 'test endpoint' do

	describe 'post /test' do

		it 'must return a 201 status code' do
			post '/test'
			last_response.status.must_equal 201
		end

	end

end