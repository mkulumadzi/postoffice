module SnailMail

	class NotificationService

		def self.send_notification person, notification
			device_token = person.device_token

			notify = APNS.send_notification(device_token, :alert => 'Hello iPhone!', :badge => 1, :sound => 'default')

			binding.pry
		end

	end

end