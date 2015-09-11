module Postoffice
	class Mail
		include Mongoid::Document
		include Mongoid::Timestamps

		extend Dragonfly::Model
		dragonfly_accessor :image
		dragonfly_accessor :thumbnail

		# belongs_to :person, foreign_key: :from_person_id
		embeds_many :correspondents

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

		# attachments: [
		# 	{
		# 		id: objectId,
		# 		type: "TEXT",
		# 		content: "blah"
		# 	}
		# 	{
		# 		id: objectId,
		# 		type: "IMAGE",
		# 		image_uid: "xxxx"
		# 	}
		# ]

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

		def conversation
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

	end

end
