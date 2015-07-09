module SnailMail

	class NotificationService

		def self.create_notification_for_people people, alert
			people_with_device_tokens = people.select{|person| person.device_token != nil }

			notifications = []

			people_with_device_tokens.each do |person|
				notifications << APNS::Notification.new(person.device_token, alert)
			end

			notifications

		end

	end

end