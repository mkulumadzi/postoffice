module Postoffice

	class MailService

		def self.create_mail person_id, data
			person = Postoffice::Person.find(person_id)

			mail_hash = Hash[from: person.username, to: data["to"], content: data["content"]]

			if data["scheduled_to_arrive"] then self.set_scheduled_to_arrive mail_hash, data end
			if data["delivery_options"] then self.set_delivery_options mail_hash, data end

			if mail_hash[:delivery_options] && mail_hash[:delivery_options].include?("EMAIL")
				self.validate_ability_to_send_email_to_recipient mail_hash
			end

			mail = Postoffice::Mail.create!(mail_hash)

			if data["image_uid"]
				mail.image = Dragonfly.app.fetch(data["image_uid"]).apply
				mail.thumbnail = mail.image.thumb('x96')
				mail.save
			end

			mail
		end

		def self.set_scheduled_to_arrive mail_hash, data
			mail_hash[:scheduled_to_arrive] = data["scheduled_to_arrive"]
			mail_hash[:type] = "SCHEDULED"
		end

		def self.set_delivery_options mail_hash, data
			if invalid_delivery_options? data["delivery_options"]
				raise "Invalid delivery options"
			else
				mail_hash[:delivery_options] = data["delivery_options"]
			end
		end

		def self.invalid_delivery_options? delivery_options
			valid_delivery_options = ["SLOWPOST", "EMAIL"]
			if (delivery_options - valid_delivery_options).count > 0
				true
			else
				false
			end
		end

		def self.validate_ability_to_send_email_to_recipient mail_hash
			begin
				person = Postoffice::Person.find_by(username: mail_hash[:to])
				if self.invalid_email? person.email then raise "User does not have an email address" end
			rescue Mongoid::Errors::DocumentNotFound
				if self.invalid_email? mail_hash[:to] then raise "Invalid email address" end
			end
		end

		def self.invalid_email? email
			valid_email_regex = /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z]+)*\.[a-z]+\z/
			if email && email.match(valid_email_regex) != nil
				return false
			else
				return true
			end
		end

		def self.ensure_mail_arrives_in_order_it_was_sent mail
			latest_incoming_mail = Postoffice::Mail.where(to: mail.to, from: mail.from, status: "SENT", type: "STANDARD").desc(:scheduled_to_arrive).limit(1).first

			if mail.scheduled_to_arrive < latest_incoming_mail.scheduled_to_arrive
				mail.scheduled_to_arrive = latest_incoming_mail.scheduled_to_arrive + 5.minutes
				mail.save
			end
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

			query = {to: username, delivery_options: "SLOWPOST", scheduled_to_arrive: { "$lte" => Time.now } }
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

				num_unread = Postoffice::Mail.where({from: person[:username], to: username, status: "DELIVERED", delivery_options: "SLOWPOST"}).count
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

		def self.find_mail_to_deliver
			Postoffice::Mail.where({status: "SENT", scheduled_to_arrive: { "$lte" => Time.now } }).to_a
		end

		def self.deliver_mail mails
			mails.each do |mail|
				mail.update_delivery_status
			end

		end

		def self.people_to_notify mails
			people = []

			mails.each do |mail|
				if mail.delivery_options.include? "SLOWPOST"
					person = Postoffice::Person.where({username: mail.to})[0]
					people << person
				end
			end

			people.uniq
		end

		#To Do: Write automated tests for this method (it is working based on manual tests)
		def self.deliver_mail_and_notify_recipients email_api_key = "POSTMARK_API_TEST"
			# Deliver mail
			mails = self.find_mail_to_deliver
			emails_to_send = self.find_emails_to_send
			self.deliver_mail mails

			# Send notifications for mail that is delivered via Slowpost
			people = self.people_to_notify mails
			self.send_notifications_to_people_receiving_mail people

			# Send emails for mail with email delivery options
			emails_to_send.each do |mail|
				self.send_email_for_mail mail, email_api_key
			end
		end

		def self.send_notifications_to_people_receiving_mail people
			notifications = Postoffice::NotificationService.create_notification_for_people people, "You've received new mail!", "New Mail"
			APNS.send_notifications(notifications)
		end

		def self.find_emails_to_send
			Postoffice::Mail.where({status: "SENT", delivery_options: "EMAIL", scheduled_to_arrive: { "$lte" => Time.now } }).to_a
		end

		def self.send_email_for_mail mail, email_api_key = "POSTMARK_API_TEST"
			email_hash = self.create_email_hash mail
			self.send_email email_hash, email_api_key
		end

		def self.create_email_hash mail
			Hash[
				from: ENV["POSTOFFICE_POSTMAN_EMAIL_ADDRESS"],
				to: self.get_email_to_send_mail_to(mail),
				subject: "You've received a Slowpost!",
				html_body: mail.content,
				track_opens: true
			]
		end

		def self.get_email_to_send_mail_to mail
			begin
				person = Postoffice::Person.find_by(username: mail.to)
				if self.invalid_email?(person.email) == false
					return person.email
				else
					raise "Person does not have a valid email address"
				end
			rescue Mongoid::Errors::DocumentNotFound
				if self.invalid_email?(mail.to) == false
					return mail.to
				else
					raise "Not addressed to a valid email address"
				end
			end
		end

		def self.send_email email_hash, email_api_key = "POSTMARK_API_TEST"
			client = Postmark::ApiClient.new(email_api_key)
			client.deliver(email_hash)
		end

	end

end
