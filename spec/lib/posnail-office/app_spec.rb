ENV['RACK_ENV'] = 'test'

require 'rack/test'
require '../spec_helper'

include Rack::Test::Methods

def app
  SnailMail::Application
end

describe 'app_root' do

	describe 'get /' do
		it 'should do something' do
			get '/'
		end
	end 
end