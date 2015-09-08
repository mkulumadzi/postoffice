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

			if data["scheduled_to_arrive"]
				mail.scheduled_to_arrive = data["scheduled_to_arrive"]
				mail.type = "SCHEDULED"
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
			if params[:updated_at] then query[:updated_at] = params[:updated_at] end
			if params[:conversation_username] then query[:from] = params[:conversation_username] end

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

			if params[:updated_at] then query[:updated_at] = params[:updated_at] end
			if params[:conversation_username] then query[:to] = params[:conversation_username] end

			Postoffice::Mail.where(query).each do |mail|
				mails << mail.as_document
			end

			mails

		end

		def self.conversation_metadata params
			penpals = self.get_contacts params
			conversations = []
			username = Postoffice::Person.find(params[:id]).username

			penpals.each do |person|

				num_unread = Postoffice::Mail.where({from: person[:username], to: username, status: "DELIVERED"}).count
				num_undelivered = Postoffice::Mail.where({from: username, to: person[:username], status: "SENT"}).count
				all_mail_query = Postoffice::Mail.or({from: username, to: person[:username]},{from: person[:username], to: username, status: {:$in => ["DELIVERED", "READ"]}})

				most_recent_updated_mail = all_mail_query.sort! {|a,b| b[:updated_at] <=> a[:updated_at]}[0]
				most_recent_arrived_mail = all_mail_query.where(scheduled_to_arrive: {:$ne => nil}).sort! {|a,b| b[:scheduled_to_arrive] <=> a[:scheduled_to_arrive]}[0]

				metadata = Hash.new
				metadata[:username] = person[:username]
				metadata[:name] = person[:name]
				metadata[:num_unread] = num_unread
				metadata[:num_undelivered] = num_undelivered
				metadata[:updated_at] = most_recent_updated_mail[:updated_at]
				metadata[:most_recent_status] = most_recent_arrived_mail[:status]
				metadata[:most_recent_sender] = most_recent_arrived_mail[:from]
				conversations << metadata

			end

			conversations
		end

		def self.conversation params
			params[:conversation_username] = Postoffice::Person.find(params[:conversation_id]).username
			from_conversation = self.outbox params
			to_conversation = self.mailbox params
			mails = from_conversation + to_conversation
			mails.sort! {|a,b| b[:created_at] <=> a[:created_at]}
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
		def self.get_people_who_received_mail_from params
			username = Postoffice::Person.find(params[:id]).username
			query = Hash[:from, username]
			if params[:updated_at] != nil then query[:updated_at] = params[:updated_at] end

			list_of_people = []
			Postoffice::Mail.where(query).each do |mail|
				list_of_people << Postoffice::Person.find_by(username: mail.to)
			end

			list_of_people.uniq
		end

		def self.get_people_who_sent_mail_to params
			username = Postoffice::Person.find(params[:id]).username
			query = Hash[to: username, status: Hash[:$in, ["DELIVERED", "READ"]]]
			if params[:updated_at] != nil then query[:updated_at] = params[:updated_at] end

			list_of_people = []
			Postoffice::Mail.where(query).each do |mail|
				list_of_people << Postoffice::Person.find_by(username: mail.from)
			end

			list_of_people.uniq
		end

		def self.get_contacts params
			recipients = self.get_people_who_received_mail_from params
			senders = self.get_people_who_sent_mail_to params
			contacts = (recipients + senders).uniq
			contacts_as_documents = []
			contacts.each do |person|
				contacts_as_documents << person.as_document
			end
			contacts_as_documents
		end

		def self.send_email email_hash, api_key
			client = Postmark::ApiClient.new(api_key)
			client.deliver(email_hash)
		end

	end

end
