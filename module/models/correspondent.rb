require 'erb'

module Postoffice
	class Correspondent
		include Mongoid::Document
		include Mongoid::Timestamps
    embedded_in :mail
  end

	class FromPerson < Correspondent
		field :person_id, type: BSON::ObjectId
	end

	class ToPerson < Correspondent
		field :person_id, type: BSON::ObjectId
		field :attempted_to_notify, type: Boolean
		field :status, type: String
		field :date_read, type: DateTime

		def read
			self.status = "READ"
			self.date_read = Time.now
			self.mail.save
		end
	end

	class Email < Correspondent
		field :email, type: String
		field :attempted_to_send, type: Boolean
	end

end
