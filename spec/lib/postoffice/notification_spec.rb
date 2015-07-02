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
			APNS.pem.must_equal 'certificates/snailtail.production.pem'
		end

	end

	describe SnailMail::NotificationService do

		let ( :person1 ) {
			person1_username = SnailMail::Person.random_username
			salt = SecureRandom.hex(64)
			hashed_password = Digest::SHA256.bubblebabble ("password" + salt)
			SnailMail::Person.create!(
				name: "Evan",
				username: "#{person1_username}",
				address1: "121 W 3rd St",
				city: "New York",
				state: "NY",
				zip: "10012",
				device_token: "4144e129b885dbf301deacdb0b427ad02f052a39cb7e5c0443d6188a483fa166"
			)		
		}

		# it 'must send the notification' do
		# 	SnailMail::NotificationService.send_notification person1, "Hello!"
		# 	last_response.must_equal "foo"
		# end

	end
	
end