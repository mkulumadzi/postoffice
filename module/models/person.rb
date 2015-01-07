module SnailMail
	class Person
		include Mongoid::Document
		include Mongoid::Timestamps

		field :username, type: String
		field :name, type: String
		field :address1, type: String
		field :city, type: String
		field :state, type: String
		field :zip, type: String

		def self.validate(name)
			self.all.map { |person| person.name }.include?(name)
		end

	end
end