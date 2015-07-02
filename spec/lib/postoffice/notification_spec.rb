require_relative '../../spec_helper'

describe APNS do

	describe 'configuration' do

		it 'must set the port to 2195' do
			APNS.port.must_equal 2195
		end

		it 'must set the gateway' do
			APNS.host.must_equal 'gateway.sandbox.push.apple.com'
		end

		it 'must set the path to the pem file' do
			APNS.pem.must_equal 'cerfificates/snailtail.development.pem'
		end

	end
	
end