module SnailMail

	class NotificationService

		def self.create_notification_for_people people, alert
			people_with_device_tokens = people.select{|person| person.device_token != nil }

			notifications = []

			people_with_device_tokens.each do |person|
				badge = self.count_unread_mail person
				notifications << APNS::Notification.new(person.device_token, :alert => alert, :badge => badge)
			end

			notifications

		end

		def self.count_unread_mail person
			SnailMail::Mail.where({to: person.username, status: "DELIVERED"}).count
		end

	end

end