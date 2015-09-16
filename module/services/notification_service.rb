module Postoffice

	class NotificationService

		def self.create_notification_for_people people, alert, type
			people_with_device_tokens = people.select{|person| person.device_token != nil }

			notifications = []

			people_with_device_tokens.each do |person|
				badge = self.count_unread_mail person
				notifications << APNS::Notification.new(person.device_token, :alert => alert, :badge => badge, :other => {:type => type})
			end

			notifications

		end

		def self.count_unread_mail person
			Postoffice::Mail.where(status: "DELIVERED", :correspondents.elem_match => { :_type => "Postoffice::ToPerson", :person_id => person.id, :status => {"$ne" => "READ"}}).count
		end

	end

end
