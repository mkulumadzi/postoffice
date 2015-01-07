module SnailMail
	class Mail
		include Mongoid::Document
		include Mongoid::Timestamps

		field :from, type: String
		field :to, type: String
		field :content, type: String
		field :status, type: String
		field :days_to_arrive, type: Integer

		def self.days_to_arrive
			(3..5).to_a.sample
		end

	end

end