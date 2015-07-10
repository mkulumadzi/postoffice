require_relative '../../spec_helper'

describe APNS do

	describe 'configuration' do

		it 'must set the port to 2195' do
			APNS.port.must_equal 2195
		end

		it 'must set the gateway' do
			APNS.host.must_equal 'gateway.sandbox.push.apple.com'
		end

		it 'must point to a pem file' do
			File.exist?(APNS.pem).must_equal true
		end

	end

	describe SnailMail::NotificationService do

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

		let ( :mail1) {
			SnailMail::Mail.create!(
				from: person1.username,
				to: person2.username,
				content: "Hey"
			)
		}

		let ( :mail2) {
			SnailMail::Mail.create!(
				from: person1.username,
				to: person2.username,
				content: "Hey"
			)
		}

		describe 'create notifications' do

			before do
				mail1.mail_it
				mail1.deliver_now
				mail1.update_delivery_status
				mail1.read

				mail2.mail_it
				mail2.deliver_now
				mail2.update_delivery_status
			end

			it 'must return the number of mail that is delivered to a person' do
				num_unread = SnailMail::NotificationService.count_unread_mail person2
				num_unread.must_equal 1
			end

			describe 'create notification for people' do

				before do
					person2.device_token = "abc123"
					people = [person1, person2]

					@notifications = SnailMail::NotificationService.create_notification_for_people people, "Hello"
				end

				it 'must return an array of APNS notifications' do
					@notifications[0].must_be_instance_of APNS::Notification
				end

				it 'must only generate notification if a person has a device token' do
					@notifications.length.must_equal 1
				end

				it 'must include the device token in the notification' do
					@notifications[0].device_token.must_equal "abc123"
				end

				it 'must include the message in the notification' do
					@notifications[0].alert.must_equal "Hello"
				end

				it 'must include the badge in the notification' do
					@notifications[0].badge.must_equal 1
				end

			end

		end

	## Possible To Do: Test that a notification was actually sent
		# let ( :person1 ) {
		# 	person1_username = SnailMail::Person.random_username
		# 	salt = SecureRandom.hex(64)
		# 	hashed_password = Digest::SHA256.bubblebabble ("password" + salt)
		# 	SnailMail::Person.create!(
		# 		name: "Evan",
		# 		username: "#{person1_username}",
		# 		address1: "121 W 3rd St",
		# 		city: "New York",
		# 		state: "NY",
		# 		zip: "10012",
		# 		device_token: "4144e129b885dbf301deacdb0b427ad02f052a39cb7e5c0443d6188a483fa166"
		# 	)		
		# }

		# it 'must send the notification' do
		# 	SnailMail::NotificationService.send_notification person1, "Hello my friend"
		# 	last_response.must_equal "foo"
		# end

	end
	
end