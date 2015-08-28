module Postoffice
	class Mail
		include Mongoid::Document
		include Mongoid::Timestamps

		extend Dragonfly::Model
		dragonfly_accessor :image
		dragonfly_accessor :thumbnail

		field :from, type: String
		field :to, type: String
		field :content, type: String
		field :image_uid, type: String
		field :thumbnail_uid
		field :status, type: String, default: "DRAFT"
		field :scheduled_to_arrive, type: DateTime

		def days_to_arrive
			(1..2).to_a.sample
		end

		def arrive_when
			Time.now + days_to_arrive * 86400
		end

		def mail_it
			raise ArgumentError, "Mail must be in DRAFT state to send" unless self.status == "DRAFT"
			self.status = "SENT"
			self.scheduled_to_arrive = arrive_when
			self.save
		end

		def make_it_arrive_now
			raise ArgumentError, "Mail must be in SENT state to deliver" unless self.status == "SENT"
			self.scheduled_to_arrive = Time.now
			self.save
		end

		def update_delivery_status
			if self.scheduled_to_arrive && self.scheduled_to_arrive <= Time.now && self.status == "SENT"
				self.status = "DELIVERED"
				self.save
			end
		end

		def read
			raise ArgumentError, "Mail must be in DELIVERED state to read" unless self.status == "DELIVERED"
			self.status = "READ"
			self.save
		end

	end

end
