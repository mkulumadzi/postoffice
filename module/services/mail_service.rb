module Postoffice

	class MailService

		def self.create_mail params, json_data
			person = Postoffice::Person.find(params[:id])
			mail_hash = self.create_mail_hash person.id, json_data
			mail = Postoffice::Mail.create!(mail_hash)
			# self.add_image mail
			self.create_conversation_if_none_exists mail
			mail
		end

		def self.create_mail_hash person_id, json_data
			mail_hash = self.initialize_mail_hash_with_from_person person_id
			mail_hash = self.add_content mail_hash, json_data
			mail_hash = self.add_correspondents mail_hash, json_data
			mail_hash = self.set_scheduled_to_arrive mail_hash, json_data
		end

		def self.initialize_mail_hash_with_from_person person_id
			Hash(correspondents: [Postoffice::FromPerson.new(person_id: person_id)])
		end

		def self.add_content mail_hash, json_data
			mail_hash [:content] = json_data["content"]
			mail_hash
		end

		# @data = '{"content": "Hey what is up", "correspondents": {"to_people": ["' + @person2.id.to_s '","' + @person3.id.to_s '"], "emails": ["test@test.com", "test2@test.com"]}'

		def self.add_correspondents mail_hash, json_data
			correspondents = self.create_to_person_correspondents json_data
			correspondents += self.create_email_correspondents json_data
			mail_hash[:correspondents] = correspondents
			mail_hash
		end

		def self.create_to_person_correspondents json_data
			correspondents = []
			to_person_list = json_data["correspondents"]["to_people"]
			if to_person_list
				to_person_list.each { |id| correspondents << self.create_correspondent_from_person_id_string(id) }
			end
			correspondents
		end

		def self.create_correspondent_from_person_id_string person_id_s
			Postoffice::ToPerson.new(person_id: BSON::ObjectId(person_id_s))
		end

		def self.create_email_correspondents json_data
			correspondents = []
			email_list = json_data["correspondents"]["emails"]
			if email_list
				email_list.each { |email| correspondents << Postoffice::Email.new(email: email ) }
			end
			correspondents
		end

		def self.set_scheduled_to_arrive mail_hash, json_data
			if json_data["scheduled_to_arrive"] then
				mail_hash[:scheduled_to_arrive] = json_data["scheduled_to_arrive"]
				mail_hash[:type] = "SCHEDULED"
				mail_hash
			else
				mail_hash
			end
		end

		def self.create_conversation_if_none_exists mail
			if Postoffice::Conversation.where(hex_hash: mail.conversation_hash[:hex_hash]).count == 0
				Postoffice::Conversation.new(mail.conversation_hash).save
			end
		end

		# def self.add_image mail, json_data
		# 	if json_data["image_uid"]
		# 		mail.image = Dragonfly.app.fetch(data["image_uid"]).apply
		# 		mail.save
		# 	end
		# end

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
			Postoffice::Mail.where(params).to_a
		end
		### End Mark

		def self.mailbox params
			self.get_person_and_perform_mail_query params, self.query_mail_to_person
		end

		def self.get_person_and_perform_mail_query params, query_function
			person = Postoffice::Person.find(params[:id])
			query = self.mail_query(query_function, person, params)
			self.return_mail_array query
		end

		def self.mail_query mail_query_proc, person, params
			query = mail_query_proc.call(person)
			query = self.add_updated_since_to_query query, params
		end

		def self.query_mail_to_person
			Proc.new { |person| Hash(:status => "DELIVERED", :correspondents.elem_match => {"_type" => "Postoffice::ToPerson", "person_id" => person.id} ) }
		end

		def self.add_updated_since_to_query query, params
			if params[:updated_at] then query[:updated_at] = params[:updated_at] end
			query
		end

		def self.return_mail_array query
			Postoffice::Mail.where(query).to_a
		end

		def self.outbox params
			self.get_person_and_perform_mail_query params, self.query_mail_from_person
		end

		def self.query_mail_from_person
			Proc.new { |person| Hash(:correspondents.elem_match => {"_type" => "Postoffice::FromPerson", "person_id" => person.id} ) }
		end

		### Scheduled tasks for delivering mail and sending notifications and emails

		def self.deliver_mail_and_notify_correspondents email_api_key = "POSTMARK_API_TEST"
			delivered_mail = self.deliver_mail_that_has_arrived
			correspondents = self.get_correspondents_to_notify_from_mail delivered_mail
			self.send_notifications_to_people_receiving_mail correspondents[:to_people]
			self.send_emails_for_mail correspondents[:email], email_api_key
		end

		def self.deliver_mail_that_has_arrived
			mails = self.find_mail_that_has_arrived
			mails.each { |mail| mail.deliver }
			mails
		end

		def self.find_mail_that_has_arrived
			Postoffice::Mail.where({status: "SENT", scheduled_to_arrive: { "$lte" => Time.now } }).to_a
		end

		def self.get_correspondents_to_notify_from_mail mail_array
			correspondents = Hash[:to_people, [], :emails, []]
			mail_array.each do |mail|
				mail.correspondents.each do |c|
					if c._type == "Postoffice::ToPerson" && c.attempted_to_notify != true
						correspondents[:to_people] << c
					elsif c._type == "Postoffice::Email" && c.attempted_to_send != true
						correspondents[:emails] << c
					end
				end
			end
			correspondents
		end

		def self.send_notifications_to_people_receiving_mail to_people
			people = self.get_people_from_correspondents to_people
			notifications = Postoffice::NotificationService.create_notification_for_people people, "You've received new mail!", "New Mail"
			APNS.send_notifications(notifications)
			self.mark_attempted_notification to_people
		end

		def self.get_people_from_correspondents correspondents
			people = []
			correspondents.each { |c| people << Postoffice::Person.find(c.person_id) }
			people
		end

		def self.mark_attempted_notification correspondents
			correspondents.each do |c|
				c.attempted_to_notify = true
				c.save
			end
		end

		def self.send_emails_for_mail correspondents, email_api_key = "POSTMARK_API_TEST"
			emails = self.create_emails_to_send_to_correspondents correspondents
			emails.each { |email| self.send_email email, email_api_key }
			self.mark_attempt_to_send_email correspondents
		end

		def self.create_emails_to_send_to_correspondents correspondents
			emails = []
			correspondents.each { |c| emails << self.create_email(c) }
			emails
		end

		def self.create_email correspondent
			Hash[
				from: ENV["POSTOFFICE_POSTMAN_EMAIL_ADDRESS"],
				to: correspondent.email,
				subject: "You've received a Slowpost!",
				html_body: correspondent.mail.content,
				track_opens: true
			]
		end

		def self.send_email email, email_api_key = "POSTMARK_API_TEST"
			client = Postmark::ApiClient.new(email_api_key)
			client.deliver(email)
		end

		def self.mark_attempt_to_send_email correspondents
			correspondents.each do |c|
				c.attempted_to_send = true
				c.save
			end
		end

		### Functions for viewing lists of conversations, conversation metadata and mail within a conversation


		# def self.get_contacts params
		# 	recipients = self.get_people_who_received_mail_from params
		# 	senders = self.get_people_who_sent_mail_to params
		# 	contacts = (recipients + senders).uniq
		# 	contacts_as_documents = []
		# 	contacts.each do |person|
		# 		contacts_as_documents << person.as_document
		# 	end
		# 	contacts_as_documents
		# end
		#
		# # Get people who have sent or received mail to the person
		# def self.get_people_who_received_mail_from params
		# 	query = Hash[:from_person_id, BSON::ObjectId(params[:id])]
		# 	if params[:updated_at] != nil then query[:updated_at] = params[:updated_at] end
		#
		# 	list_of_people = []
		# 	Postoffice::Mail.where(query).each do |mail|
		# 		mail.recipients.each do |recipient|
		# 			list_of_people << Postoffice::Person.find(recipient.person_id)
		# 		end
		# 	end
		#
		# 	list_of_people.uniq
		# end
		#
		# def self.get_people_who_sent_mail_to params
		# 	id = BSON::ObjectId(params[:id])
		# 	query = Hash["recipients.person_id" => id, status: "DELIVERED"]
		# 	if params[:updated_at] != nil then query[:updated_at] = params[:updated_at] end
		#
		# 	list_of_people = []
		# 	Postoffice::Mail.where(query).each do |mail|
		# 		list_of_people << Postoffice::Person.find(mail.from_person_id)
		# 	end
		#
		# 	list_of_people.uniq
		# end

	end

end
