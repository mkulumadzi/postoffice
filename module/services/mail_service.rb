module Postoffice

	class MailService

		def self.create_mail params, json_data
			person = Postoffice::Person.find(params[:id])
			mail_hash = self.create_mail_hash person.id, json_data
			mail = Postoffice::Mail.create!(mail_hash)
			self.create_conversation_if_none_exists mail
			mail
		end

		def self.create_mail_hash person_id, json_data
			mail_hash = self.initialize_mail_hash_with_from_person person_id
			mail_hash = self.add_correspondents mail_hash, json_data
			mail_hash = self.add_attachments mail_hash, json_data
			mail_hash = self.set_scheduled_to_arrive mail_hash, json_data
		end

		def self.initialize_mail_hash_with_from_person person_id
			Hash(correspondents: [Postoffice::FromPerson.new(person_id: person_id)])
		end

		def self.add_correspondents mail_hash, json_data
			correspondents = self.add_embedded_documents json_data["correspondents"]["to_people"], self.create_person_correspondent
			correspondents += self.add_embedded_documents json_data["correspondents"]["emails"], self.create_email_correspondent
			mail_hash[:correspondents] += correspondents
			mail_hash
		end

		def self.add_embedded_documents source_data, create_document_function
			documents = []
			if source_data
				source_data.each { |d| documents << create_document_function.call(d) }
			end
			documents
		end

		def self.create_person_correspondent
			Proc.new { |person_id_string| Postoffice::ToPerson.new(person_id: BSON::ObjectId(person_id_string))}
		end

		def self.create_email_correspondent
			Proc.new { |email| Postoffice::Email.new(email: email)}
		end

		def self.add_attachments mail_hash, json_data
			attachments = self.add_embedded_documents json_data["attachments"]["notes"], self.add_note
			attachments += self.add_embedded_documents json_data["attachments"]["image_attachments"], self.add_image_attachment
			mail_hash[:attachments] = attachments
			mail_hash
		end

		def self.add_note
			Proc.new { |note| Postoffice::Note.new(content: note)}
		end

		def self.add_image_attachment
			Proc.new { |uid| Postoffice::ImageAttachment.new(image_uid: uid)}
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

		# Going to have to rethink this given the ability to send group mail; it would need to be relative to the group conversation...
		# def self.ensure_mail_arrives_in_order_it_was_sent mail
		# 	latest_incoming_mail = Postoffice::Mail.where(from_person_id: mail.from_person_id, "recipients.person_id" => mail.to, status: "SENT", type: "STANDARD").desc(:scheduled_to_arrive).limit(1).first
		#
		# 	if mail.scheduled_to_arrive < latest_incoming_mail.scheduled_to_arrive
		# 		mail.scheduled_to_arrive = latest_incoming_mail.scheduled_to_arrive + 5.minutes
		# 		mail.save
		# 	end
		# end

		def self.generate_welcome_message person
			message_template = File.open("templates/Welcome Message.txt")
			text = message_template.read
			message_template.close

			from_person_record = Postoffice::Person.find_by(username: ENV['POSTOFFICE_POSTMAN_USERNAME'])
			from_person = Postoffice::FromPerson.new(person_id: from_person_record.id)
			to_person = Postoffice::ToPerson.new(person_id: person.id)
			note = Postoffice::Note.new(content: text)
			welcome_image = Postoffice::ImageAttachment.new(image_uid: ENV['POSTOFFICE_WELCOME_IMAGE'])

			mail = Postoffice::Mail.new(
				correspondents: [from_person, to_person],
				attachments: [note, welcome_image]
			)

			mail.mail_it
			mail.deliver
			mail
		end

		def self.get_mail params = {}
			Postoffice::Mail.where(params).to_a
		end

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

		def self.all_mail_for_person params
			self.get_person_and_perform_mail_query params, self.query_all_mail_for_person
		end

		def self.query_all_mail_for_person
			Proc.new { |person| Hash("$or" => [{:status => "DELIVERED", :correspondents.elem_match => {"_type" => "Postoffice::ToPerson", "person_id" => person.id}},{:correspondents.elem_match => {"_type" => "Postoffice::FromPerson", "person_id" => person.id}}] ) }
		end


		## Custom hash for returning mail for a persons consumption in an app

		def self.hash_of_mail_for_person mail, person
			mail_hash = self.mail_hash_removing_correspondents_key mail
			mail_hash["conversation_id"] = mail.conversation.id.to_s
			mail_hash["from_person_id"] = mail.from_person.id.to_s
			mail_hash["to_people_ids"] = mail.to_people_ids
			mail_hash["to_emails"] = mail.to_emails
			mail_hash["my_info"] = self.mail_info_for_person mail, person
			self.replace_image_uids_with_urls mail_hash
			mail_hash
		end

		def self.mail_hash_removing_correspondents_key mail
			JSON.parse(mail.as_document.to_json(:except => ["correspondents"]))
		end

		def self.mail_info_for_person mail, person
			correspondent = mail.correspondents.find_by(person_id: person.id)
			correspondent.as_document
		end

		def self.replace_image_uids_with_urls mail_hash
			image_attachments = mail_hash["attachments"].select {|a| a["_type"] == "Postoffice::ImageAttachment"}
			if image_attachments.count > 0
				image_attachments.each do |i|
					i["url"] = "#{ENV['POSTOFFICE_BASE_URL']}/image/#{i["image_uid"]}"
					i.delete("image_uid")
				end
			end
		end

		### Scheduled tasks for delivering mail and sending notifications and emails

		def self.deliver_mail_and_notify_correspondents email_api_key = "POSTMARK_API_TEST"
			delivered_mail = self.deliver_mail_that_has_arrived
			correspondents = self.get_correspondents_to_notify_from_mail delivered_mail
			self.send_notifications_to_people_receiving_mail correspondents[:to_people]
			self.send_emails_for_mail correspondents[:emails], email_api_key
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
				c.mail.save
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
				html_body: correspondent.mail.notes[0].content,
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
				c.mail.save
			end
		end

	end

end
