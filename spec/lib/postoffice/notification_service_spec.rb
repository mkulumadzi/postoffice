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

	describe Postoffice::NotificationService do

		before do

			@person1 = create(:person, username: random_username, phone: random_phone, email: random_email, device_token: nil)
			@person2 = create(:person, username: random_username, phone: random_phone, email: random_email, device_token: "abc123")

			@mail1 = create(:mail, correspondents: [build(:from_person, person_id: @person1.id), build(:to_person, person_id: @person2.id)])
			@mail2 = create(:mail, correspondents: [build(:from_person, person_id: @person1.id), build(:to_person, person_id: @person2.id)])

			@mail1.mail_it
			@mail1.deliver
			@mail1.read_by @person2

			@mail2.mail_it
			@mail2.deliver
		end

		it 'must return the number of mail that is delivered to a person' do
			num_unread = Postoffice::NotificationService.count_unread_mail @person2
			num_unread.must_equal 1
		end

		describe 'create notification for people' do

			before do
				people = [@person1, @person2]

				@notifications = Postoffice::NotificationService.create_notification_for_people people, "Hello", "New Mail"
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

			it 'must include the type as "New Mail"' do
				@notifications[0].other[:type].must_equal "New Mail"
			end

		end

	end

end
