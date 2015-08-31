module Postoffice

	class MailService

		def self.create_mail person_id, data
			person = Postoffice::Person.find(person_id)

	    mail = Postoffice::Mail.create!({
	      from: person.username,
	      to: data["to"],
	      content: data["content"]
	    })

			if data["image_uid"]
				mail.image = Dragonfly.app.fetch(data["image_uid"]).apply
				mail.thumbnail = mail.image.thumb('x96')
				mail.save
			end

			if data["type"]
				mail.type = data["type"]
				mail.save
			end

			mail
		end

		def self.ensure_mail_arrives_in_order_it_was_sent mail
			latest_incoming_mail = Postoffice::Mail.where(to: mail.to, from: mail.from, status: "SENT", type: "STANDARD").desc(:scheduled_to_arrive).limit(1).first

			if mail.scheduled_to_arrive < latest_incoming_mail.scheduled_to_arrive
				mail.scheduled_to_arrive = latest_incoming_mail.scheduled_to_arrive + 5.minutes
				mail.save
			end
		end

		def self.get_mail params = {}
			mails = []
			Postoffice::Mail.where(params).each do |mail|
				mails << mail.as_document
			end
			mails
		end

		def self.mailbox params
			username = Postoffice::Person.find(params[:id]).username
			mails = []

			query = {to: username, scheduled_to_arrive: { "$lte" => Time.now } }

			if params[:updated_at]
				query[:updated_at] = params[:updated_at]
			end

			Postoffice::Mail.where(query).each do |mail|
				mail.update_delivery_status
				mails << mail.as_document
			end

			mails
		end

		def self.outbox params
			username = Postoffice::Person.find(params[:id]).username
			mails = []

			query = {from: username}

			if params[:updated_at]
				query[:updated_at] = params[:updated_at]
			end

			Postoffice::Mail.where(query).each do |mail|
				mails << mail.as_document
			end

			mails

		end

		def self.generate_welcome_message person
			text = File.open("templates/Welcome Message.txt").read

			mail = Postoffice::Mail.create!({
				from: ENV['POSTOFFICE_POSTMAN_USERNAME'],
				to: person.username,
				content: text,
				image_uid: ENV['POSTOFFICE_WELCOME_IMAGE']
			})

			mail.mail_it
			mail.make_it_arrive_now

		end

		def self.find_mail_to_deliver
			mails = []

			Postoffice::Mail.where({status: "SENT", scheduled_to_arrive: { "$lte" => Time.now } }).each do |mail|
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
				person = Postoffice::Person.where({username: mail.to})[0]
				people << person
			end

			people.uniq
		end

		#To Do: Write automated tests for this method (it is working based on manual tests)
		def self.deliver_mail_and_notify_recipients
			mails = self.find_mail_to_deliver
			self.deliver_mail mails
			people = self.people_to_notify mails
			notifications = Postoffice::NotificationService.create_notification_for_people people, "You've received new mail!", "New Mail"
			puts "Sending notifications: #{notifications}"
			APNS.send_notifications(notifications)
		end

		# Get people who have sent or received mail to the person
		def self.get_people_who_received_mail_from username
			list_of_people = []

			Postoffice::Mail.where(from: username).each do |mail|
				list_of_people << Postoffice::Person.find_by(username: mail.to)
			end

			list_of_people
		end

		def self.get_people_who_sent_mail_to username
			list_of_people = []

			Postoffice::Mail.where(to: username).each do |mail|
				list_of_people << Postoffice::Person.find_by(username: mail.from)
			end

			list_of_people
		end

		def self.get_contacts username
			recipients = self.get_people_who_received_mail_from username
			senders = self.get_people_who_sent_mail_to username

			contacts = []
			recipients.concat(senders).uniq.each do |person|
				contacts << person.as_document
			end

			contacts
		end

	end

end
