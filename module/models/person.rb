module Postoffice
	class Person
		include Mongoid::Document
		include Mongoid::Timestamps

		has_many :mail
		# has_many :slowpost_recipients

		field :username, type: String
		field :name, type: String
		field :email, type: String
		field :phone, type: String
		field :hashed_password, type: String
		field :salt, type: String
		field :address1, type: String
		field :city, type: String
		field :state, type: String
		field :zip, type: String
		field :device_token, type: String

		index({ username: 1 }, { unique: true })
		index({ email: 1 })
		index({ phone: 1 })

		def initials
			split_name = self.name.split(' ')
			if split_name.length == 1
				self.name[0..1]
			else
				split_name[0][0] + split_name[split_name.length - 1][0]
			end
		end

	end
end
