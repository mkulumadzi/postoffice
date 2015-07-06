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

	end

end