module SnailMail
	class Person
		include Mongoid::Document
		include Mongoid::Timestamps

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

		#Generate a random username as a hack to get around the unique index
		def self.random_username
			(0...8).map { (65 + rand(26)).chr }.join
		end
		
	end
end