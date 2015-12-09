module Postoffice
	class Mail
		include Mongoid::Document
		include Mongoid::Timestamps

		extend Dragonfly::Model
		dragonfly_accessor :image

		# belongs_to :person, foreign_key: :from_person_id
		embeds_many :correspondents, cascade_callbacks: true
		embeds_many :attachments, cascade_callbacks: true

		# These fields are going to be migrated, then deleted
		field :from, type: String
		field :to, type: String
		field :content, type: String
		field :image_uid, type: String
		field :thumbnail_uid

		field :type, type: String, default: "STANDARD"
		field :scheduled_to_arrive, type: DateTime

		# Statuses include DRAFT, SENT, DELIVERED
		field :status, type: String, default: "DRAFT"
		field :date_sent, type: DateTime
		field :date_delivered, type: DateTime

		def conversation_hash
			conversation_hash = Hash(people: self.people_correspondent_ids)
			if self.has_email_correspondents? then conversation_hash[:emails] = self.email_correspondents end
			conversation_hash = self.add_hex_hash_to_conversation conversation_hash
		end

		def conversation
			Postoffice::Conversation.find_or_create_by(self.conversation_hash)
		end

		def people_correspondent_ids
			people = []
			self.correspondents.or({_type: "Postoffice::FromPerson"},{_type: "Postoffice::ToPerson"}).each do |c|
				people << Postoffice::Person.find(c.person_id).id
			end
			people.sort{|a,b| a <=> b}
		end

		def has_email_correspondents?
			if self.correspondents.where(_type: "Postoffice::Email").count > 0
				return true
			else
				return false
			end
		end

		def email_correspondents
			emails = []
			self.correspondents.where(_type: "Postoffice::Email").each do |c|
				emails << c.email
			end
			emails.sort{|a,b| a <=> b }
		end

		def add_hex_hash_to_conversation conversation
			conversation[:hex_hash] = Digest::SHA1.hexdigest(conversation.to_s)
			conversation
		end

		def conversation_query
			query = self.initialize_conversation_query
			query = self.add_people_to_conversation_query query
			query = self.add_emails_to_conversation_query query
			query
		end

		def initialize_conversation_query
			num_correspondents = self.correspondents.count
			Postoffice::Mail.where("correspondents.#{num_correspondents}" => { "$exists" => false })
		end

		def add_people_to_conversation_query query
			from_person_id = self.correspondents.where(_type: "Postoffice::FromPerson")[0].person_id
			people_array = [from_person_id]
			self.correspondents.where(_type: "Postoffice::ToPerson").each { |r| people_array << r.person_id }
			query.all_in("correspondents.person_id" => people_array)
		end

		def add_emails_to_conversation_query query
			if self.correspondents.where(_type: "Postoffice::Email").count > 0
				email_array = []
				self.correspondents.where(_type: "Postoffice::Email").each { |r| email_array << r.email }
				query.all_in("correspondents.email" => email_array)
			else
				query
			end
		end

		def notes
			self.attachments.select { |a| a._type == "Postoffice::Note"}
		end

		def image_attachments
			self.attachments.select { |a| a._type == "Postoffice::ImageAttachment"}
		end

		def days_to_arrive
			(1..2).to_a.sample
		end

		def arrive_when
			Time.now + days_to_arrive * 86400
		end

		def mail_it
			raise ArgumentError, "Mail must be in DRAFT state to send" unless self.status == "DRAFT"
			self.status = "SENT"
			self.date_sent = Time.now
			unless self.scheduled_to_arrive?
				self.scheduled_to_arrive = arrive_when
			end
			self.save
		end

		def deliver
			raise ArgumentError, "Mail must be in SENT state to deliver" unless self.status == "SENT"
			self.status = "DELIVERED"
			self.date_delivered = Time.now
			self.save
		end

		def arrive_now
			raise ArgumentError, "Mail must be in SENT state to deliver" unless self.status == "SENT"
			self.scheduled_to_arrive = Time.now
			self.save
		end

		def to_list
			list = ""
			index = 0
			self.correspondents.each do |c|
				if c._type == "Postoffice::ToPerson"
					if index > 0 then list += ", " end
					person = Postoffice::Person.find(c.person_id)
					list += person.full_name
					index += 1
				elsif c._type == "Postoffice::Email"
					if index > 0 then list += ", " end
					list += c.email
					index += 1
				end
			end
			list
		end

		def message_content
			first_note = self.attachments.where(_type: "Postoffice::Note")[0]
			first_note.content
		end

		def to_people_ids
			to_people_ids = []
			to_people = self.correspondents.where(_type: "Postoffice::ToPerson")
			to_people.each { |to_person| to_people_ids << to_person.person_id.to_s }
			to_people_ids
		end

		def to_people
			to_people = []
			self.correspondents.where(_type: "Postoffice::ToPerson").each do |to_person|
				person = Postoffice::Person.where(id: to_person.person_id).first
				if person != nil then to_people << person end
			end
			to_people
		end

		def to_emails
			to_emails = []
			emails = self.correspondents.where(_type: "Postoffice::Email")
			emails.each { |email| to_emails << email.email }
			to_emails
		end

		def read_by person
			if self.status != "DELIVERED" then raise "Mail must be DELIVERED to read" end
			correspondent = self.correspondents.find_by(person_id: person.id, _type: "Postoffice::ToPerson")
			correspondent.read
		end

		### Sending notifications
		def notifications
			notifications = self.notification_for_sender
			notifications += self.notifications_for_recipients
			notifications
		end

		def notification_for_sender
			person = self.from_person
			if person.device_token != nil
				[APNS::Notification.new(person.device_token, alert: "Your Slowpost has been delivered", badge: nil, other: {type: "Delivered Mail"})]
			else
				[]
			end
		end

		def notifications_for_recipients
			notifications = []
			self.to_people.each do |person|
				if person.device_token != nil then notifications << self.recipient_notification(person) end
			end
			notifications
		end

		def recipient_notification person
			num_unread = person.number_unread_mail
			APNS::Notification.new(person.device_token, alert: "You've received a Slowpost from #{self.from_person.full_name}", badge: num_unread, other: {type: "New Mail"})
		end

		### Creating emails for mail
		def emails
			email_array = []
			self.correspondents_to_email.each do |c|
				email_array << self.email_hash(c)
				c.attempted_to_send = true
			end
			self.save
			email_array
		end

		def correspondents_to_email
			self.correspondents.where(_type: "Postoffice::Email", attempted_to_send: {"$ne" => true})
		end

		def email_hash correspondent
			attachments = correspondent.image_attachments
			mail_image_attachment = self.mail_image_attachment
			mail_image_cid = mail_image_attachment["ContentID"]
			attachments << mail_image_attachment

			template = correspondent.template
			variables = Hash(mail: self, image_cid: mail_image_cid)

			Hash[
				from: ENV["POSTOFFICE_POSTMAN_EMAIL_ADDRESS"],
				to: correspondent.email,
				subject: "#{self.from_person.full_name} sent you a Slowpost!",
				html_body: Postoffice::EmailService.generate_email_message_body(template, variables),
				track_opens: true,
				attachments: attachments
			]
		end

		def mail_image_attachment
			if self.image_attachments.count > 0
				self.create_attachment_from_mail_image
			else
				Postoffice::EmailService.image_email_attachment("resources/default_card.png")
			end
		end

		def create_attachment_from_mail_image
			first_attachment = self.image_attachments[0]
			filename = "tmp/#{first_attachment.image.name}"
			Dragonfly.app.fetch(first_attachment.image_uid).to_file(filename)
			attachment = Postoffice::EmailService.image_email_attachment(filename)
			File.delete(filename)
			attachment
		end

		def send_preview_email_if_necessary api_key = "POSTMARK_API_TEST"
			if self.to_emails.count > 0 && Postoffice::QueueService.action_has_occurred?("SEND_PREVIEW_EMAIL", self.from_person.id) == false
				self.send_preview_email api_key
			end
		end

		def send_preview_email api_key = "POSTMARK_API_TEST"
			Postoffice::QueueService.log_action_occurrence "SEND_PREVIEW_EMAIL", self.from_person.id
			Postoffice::EmailService.send_email self.preview_email_hash, api_key
		end

		def preview_email_hash
			banner_image_attachment = Postoffice::EmailService.image_email_attachment("resources/slowpost_banner.png")
			mail_image_attachment = self.mail_image_attachment
			mail_image_cid = mail_image_attachment["ContentID"]
			template = 'resources/preview_email_template.html'
			variables = Hash(mail: self, image_cid: mail_image_cid)

			Hash[
				from: ENV["POSTOFFICE_POSTMAN_EMAIL_ADDRESS"],
				to: self.from_person.email,
				subject: "Preview of your Slowpost to #{self.to_email_list_shorthand}",
				html_body: Postoffice::EmailService.generate_email_message_body(template, variables),
				track_opens: true,
				attachments: [mail_image_attachment, banner_image_attachment]
			]
		end

		def to_email_list_shorthand
			if self.to_emails.count == 1
				self.to_emails[0]
			elsif self.to_emails.count == 2
				"#{self.to_emails[0]} and #{self.to_emails[1]}"
			elsif self.to_emails.count > 2
				"#{self.to_emails[0]} and #{self.to_emails.count - 1} others"
			end
		end

		def deliver_and_notify_recipients email_api_key = "POSTMARK_API_TEST"
			self.status == "SENT" ? self.deliver : nil
			self.notify_slowpost_recipients
			self.send_emails
		end

		def notify_slowpost_recipients
			notifications = self.notifications_for_recipients
			APNS.send_notifications(notifications)
		end

		def send_emails email_api_key = "POSTMARK_API_TEST"
			self.emails.each { |email| Postoffice::EmailService.send_email email, email_api_key }
		end

		def from_person
			from_person_id = self.correspondents.where(_type: "Postoffice::FromPerson").first.person_id
			Postoffice::Person.find(from_person_id)
		end

	end

end
