module SnailMail
	class Mail
		include Mongoid::Document
		include Mongoid::Timestamps

		field :from, type: String
		field :to, type: String
		field :content, type: String
		field :status, type: String, default: "DRAFT"
		field :scheduled_to_arrive, type: DateTime

		def days_to_arrive
			(3..5).to_a.sample
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

	end

end