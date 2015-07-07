module SnailMail

	class MailService

		def self.create_mail person_id, data
			person = SnailMail::Person.find(person_id)

		    mail = SnailMail::Mail.create!({
		      from: person.username,
		      to: data["to"],
		      content: data["content"],
		      image: data["image"]
		    })
		end

		def self.get_mail params = {}
			mails = []
			SnailMail::Mail.where(params).each do |mail|
				mails << mail.as_document
			end
			mails
		end

		def self.mailbox params
			username = SnailMail::Person.find(params[:id]).username
			mails = []

			SnailMail::Mail.where({to: username, scheduled_to_arrive: { "$lte" => Time.now } }).each do |mail|
				mail.update_delivery_status
				mails << mail.as_document
			end

			mails
		end

		def self.outbox params
			username = SnailMail::Person.find(params[:id]).username
			mails = []

			SnailMail::Mail.where({from: username}).each do |mail|
				mails << mail.as_document
			end

			mails

		end

		def self.generate_welcome_message person
			text = File.open("templates/Welcome Message.txt").read

			mail = SnailMail::Mail.create!({
				from: "snailmail.kuyenda@gmail.com",
				to: person.username,
				content: text,
				image: "SnailMail Postman.png"
			})

			mail.mail_it
			mail.deliver_now

		end

		def self.find_mail_to_deliver
			mails = []

			SnailMail::Mail.where({status: "SENT", scheduled_to_arrive: { "$lte" => Time.now } }).each do |mail|
				mails << mail
			end

			mails

		end

		def self.deliver_mail mails
			mails.each do |mail|
				mail.update_delivery_status
			end

		end

		def self.people_to_notify mails
			people = []

			mails.each do |mail|
				person = SnailMail::Person.where({username: mail.to})[0]
				people << person
			end

			people.uniq
		end

		#To Do: Write automated tests for this method (it is working based on manual tests)
		def self.deliver_mail_and_notify_recipients

			mails = self.find_mail_to_deliver

			self.deliver_mail mails

			people = self.people_to_notify mails

			notifications = SnailMail::NotificationService.create_notification_for_people people, "You've received new mail!"

			APNS.send_notifications(notifications)

		end

	end

end