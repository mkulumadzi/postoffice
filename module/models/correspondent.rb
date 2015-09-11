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
			self.save
		end
	end

	class Email < Correspondent
		field :email, type: String
		field :attempted_to_send, type: Boolean
	end

  # class SlowpostRecipient < Recipient
	# 	field :person_id, type: BSON::ObjectId
  #   # field :date_notification_sent, type: DateTime
	# 	field :attempted_to_notify, type: Boolean
  #   field :status, type: String
	# 	field :date_read, type: DateTime
	#
	# 	def read
	# 		self.status = "READ"
	# 		self.date_read = Time.now
	# 		self.save
	# 	end
	#
  # end
	#
  # class EmailRecipient < Recipient
  #   field :email, type: String
	# 	field :attempted_to_send, type: Boolean
  #   # field :date_email_sent, type: DateTime
  # end

end
