module Postoffice

	class MailService

		def self.create_mail person_id, data
			person = Postoffice::Person.find(person_id)
			mail_hash = Hash[person: person, content: data["content"]]
			mail_hash[:recipients] = self.create_recipients(data["recipients"])
			if data["scheduled_to_arrive"] then self.set_scheduled_to_arrive mail_hash, data end

			mail = Postoffice::Mail.create!(mail_hash)

			if data["image_uid"]
				mail.image = Dragonfly.app.fetch(data["image_uid"]).apply
				mail.thumbnail = mail.image.thumb('x96')
				mail.save
			end

			mail
		end

		def self.create_recipients recipient_array
			recipients = []
			recipient_array.each do |r|
				if r["person_id"]
					person = Postoffice::Person.find(r["person_id"])
					recipients << Postoffice::SlowpostRecipient.new(person_id: person.id)
				elsif r["email"]
					recipients << Postoffice::EmailRecipient.new(email: r["email"])
				end
			end
			recipients
		end

		def self.set_scheduled_to_arrive mail_hash, data
			mail_hash[:scheduled_to_arrive] = data["scheduled_to_arrive"]
			mail_hash[:type] = "SCHEDULED"
		end

		# Going to have to rethink this given the ability to send group mail; it would need to be relative to the group conversation...
		# def self.ensure_mail_arrives_in_order_it_was_sent mail
		# 	latest_incoming_mail = Postoffice::Mail.where(from_person_id: mail.from_person_id, "recipients.person_id" => mail.to, status: "SENT", type: "STANDARD").desc(:scheduled_to_arrive).limit(1).first
		#
		# 	if mail.scheduled_to_arrive < latest_incoming_mail.scheduled_to_arrive
		# 		mail.scheduled_to_arrive = latest_incoming_mail.scheduled_to_arrive + 5.minutes
		# 		mail.save
		# 	end
		# end

		### Mark: Come back to these...
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

		def self.get_mail params = {}
			mails = []
			Postoffice::Mail.where(params).each do |mail|
				mails << mail.as_document
			end
			mails
		end
		### End Mark


		def self.mailbox params
			mails = []

			id = BSON::ObjectId(params[:id])
			query = {status: "DELIVERED", "recipients.person_id" => id}
			if params[:updated_at] then query[:updated_at] = params[:updated_at] end
			if params[:conversation_person_id] then query[:from_person_id] = params[:conversation_person_id] end

			Postoffice::Mail.where(query).each do |mail|
				mails << mail.as_document
			end

			mails
		end

		def self.outbox params
			mails = []

			query = {from_person_id: params[:id]}

			if params[:updated_at] then query[:updated_at] = params[:updated_at] end
			if params[:conversation_person_id] then query["recipients.person_id"] = params[:conversation_person_id] end

			Postoffice::Mail.where(query).each do |mail|
				mails << mail.as_document
			end

			mails
		end

		### Scheduled tasks for delivering mail and sending notifications and emails

		def self.deliver_mail_and_notify_recipients email_api_key = "POSTMARK_API_TEST"
			delivered_mail = self.deliver_mail_that_has_arrived
			recipients = self.get_recipients_to_notify_from_mail delivered_mail
			self.send_notifications_to_people_receiving_mail recipients[:slowpost]
			self.send_emails_for_mail recipients[:email], email_api_key
		end

		def self.deliver_mail_that_has_arrived
			mails = self.find_mail_that_has_arrived
			mails.each do |mail|
				mail.deliver
			end
			mails
		end

		def self.find_mail_that_has_arrived
			Postoffice::Mail.where({status: "SENT", scheduled_to_arrive: { "$lte" => Time.now } }).to_a
		end

		def self.get_recipients_to_notify_from_mail mail_array
			recipients = Hash[:slowpost, [], :email, []]
			mail_array.each do |mail|
				mail.recipients.each do |r|
					if r._type == "Postoffice::SlowpostRecipient" && r.attempted_to_notify != true
						recipients[:slowpost] << r
					elsif r._type == "Postoffice::EmailRecipient" && r.attempted_to_send != true
						recipients[:email] << r
					end
				end
			end
			recipients
		end

		def self.send_notifications_to_people_receiving_mail recipients
			people = self.get_people_from_recipients recipients
			notifications = Postoffice::NotificationService.create_notification_for_people people, "You've received new mail!", "New Mail"
			APNS.send_notifications(notifications)
			self.mark_attempted_notification recipients
		end

		def self.get_people_from_recipients recipients
			people = []
			recipients.each do |r|
				people << Postoffice::Person.find(r.person_id)
			end
			people
		end

		def self.mark_attempted_notification recipients
			recipients.each do |r|
				r.attempted_to_notify = true
				r.save
			end
		end

		def self.send_emails_for_mail recipients, email_api_key = "POSTMARK_API_TEST"
			emails = self.create_emails_to_send_to_recipients recipients
			emails.each { |email| self.send_email email, email_api_key }
			self.mark_attempt_to_send_email recipients
		end

		def self.create_emails_to_send_to_recipients recipients
			emails = []
			recipients.each do |recipient|
				emails << self.create_email(recipient)
			end
			emails
		end

		def self.create_email recipient
			Hash[
				from: ENV["POSTOFFICE_POSTMAN_EMAIL_ADDRESS"],
				to: recipient.email,
				subject: "You've received a Slowpost!",
				html_body: recipient.mail.content,
				track_opens: true
			]
		end

		def self.send_email email, email_api_key = "POSTMARK_API_TEST"
			client = Postmark::ApiClient.new(email_api_key)
			client.deliver(email)
		end

		def self.mark_attempt_to_send_email recipients
			recipients.each do |r|
				r.attempted_to_send = true
				r.save
			end
		end

		### Functions for viewing lists of conversations, conversation metadata and mail within a conversation

		# Get mail that the person can know about (either mail they have sent, or mail that has been delivered to them)
		# Get a unique list of the people involved in each mail (ie, any senders, any recipients, either Slowpost or Email)
		# Group the mail into 'conversations' using these unique lists
		# Allow these conversations to be returned
		# Provide a summary of some stats for each conversation, by aggregating the conversation

		def query_all_mail_for_a_person person
			Postoffice::Mail.or({from_person_id: person.id},{"recipients.person_id" => person.id, status: "DELIVERED"})
		end

		def get_participants_from_mail person, mail
			participants = [mail.from_person_id]
			participants << mail.recipient_list
			participants.delete(person.id)
			participants
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

		# Get people who have sent or received mail to the person
		def self.get_people_who_received_mail_from params
			query = Hash[:from_person_id, BSON::ObjectId(params[:id])]
			if params[:updated_at] != nil then query[:updated_at] = params[:updated_at] end

			list_of_people = []
			Postoffice::Mail.where(query).each do |mail|
				mail.recipients.each do |recipient|
					list_of_people << Postoffice::Person.find(recipient.person_id)
				end
			end

			list_of_people.uniq
		end

		def self.get_people_who_sent_mail_to params
			id = BSON::ObjectId(params[:id])
			query = Hash["recipients.person_id" => id, status: "DELIVERED"]
			if params[:updated_at] != nil then query[:updated_at] = params[:updated_at] end

			list_of_people = []
			Postoffice::Mail.where(query).each do |mail|
				list_of_people << Postoffice::Person.find(mail.from_person_id)
			end

			list_of_people.uniq
		end

		def self.conversation_metadata params
			penpals = self.get_contacts params
			conversations = []
			id = BSON::ObjectId(params[:id])

			penpals.each do |person|

				num_unread = Postoffice::Mail.where({from_person_id: person["_id"], "recipients.person_id" => id, status: "DELIVERED"}).count
				num_undelivered = Postoffice::Mail.where({from_person_id: id, "recipients.person_id" => person["_id"], status: "SENT"}).count
				all_mail_query = Postoffice::Mail.or({from_person_id: id, "recipients.person_id" => person["_id"]},{from_person_id: person["_id"], "recipients.person_id" => id, status: "DELIVERED"})

				most_recent_updated_mail = all_mail_query.sort! {|a,b| b[:updated_at] <=> a[:updated_at]}[0]
				most_recent_arrived_mail = all_mail_query.where(scheduled_to_arrive: {:$ne => nil}).sort! {|a,b| b[:scheduled_to_arrive] <=> a[:scheduled_to_arrive]}[0]

				metadata = Hash.new
				metadata[:person_id] = person["_id"]
				metadata[:username] = person["username"]
				metadata[:name] = person["name"]
				metadata[:num_unread] = num_unread
				metadata[:num_undelivered] = num_undelivered
				metadata[:updated_at] = most_recent_updated_mail[:updated_at]
				metadata[:most_recent_status] = most_recent_arrived_mail[:status]
				metadata[:most_recent_sender] = most_recent_arrived_mail[:from_person_id]
				conversations << metadata

			end

			conversations
		end

		def self.conversation params
			from_conversation = self.outbox params
			to_conversation = self.mailbox params
			mails = from_conversation + to_conversation
			mails.sort! {|a,b| b[:created_at] <=> a[:created_at]}
		end

	end

end
