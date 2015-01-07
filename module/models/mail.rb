module SnailMail
	class Mail
		include Mongoid::Document
		include Mongoid::Timestamps

		field :from, type: String
		field :to, type: String
		field :content, type: String
		field :status, type: String

	end
end