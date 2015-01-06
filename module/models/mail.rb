module SnailMail
	class Mail
		include Mongoid::Document
		include Mongoid::Timestamps

		field :id, type: String
		field :from, type: String
		field :to, type: String
		field :content, type: String
		# field :sent, type: DateTime
		field :status, type: String

		def self.validate(to)
			self.all.map { |message| message.to }.include?(to)
		end

	end
end