ENV['RACK_ENV'] = 'test'

require 'rack/test'
require 'minitest/autorun'
require_relative '../../spec_helper'

include Rack::Test::Methods

def app
  Sinatra::Application
end

describe 'app_root' do

	describe 'get /' do
		it 'should do something' do
			get '/'
		end
	end 
end