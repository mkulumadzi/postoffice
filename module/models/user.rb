module SnailMail
	class User
		include Mongoid::Document
		include Mongoid::Timestamps

		field :username, type: String
		field :name, type: String
		field :address1, type: String
		field :city, type: String
		field :state, type: String
		field :zip, type: String

		def self.validate(name)
			self.all.map { |user| user.name }.include?(name)
		end

	end
end