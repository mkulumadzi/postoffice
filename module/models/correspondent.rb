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

		def template
			if Postoffice::Person.where(email: self.email).count > 0
				'resources/existing_user_email_template.html'
			elsif Postoffice::Mail.where(:correspondents.elem_match => {"_type" => "Postoffice::Email", "email": self.email, "attempted_to_send" => true}).count > 0
				'resources/repeat_recipient_email_template.html'
			else
				'resources/new_recipient_email_template.html'
			end
		end

		def image_attachments
			banner_image_attachment = Postoffice::EmailService.image_email_attachment("resources/slowpost_banner.png")
			app_store_icon = Postoffice::EmailService.image_email_attachment("resources/app_store_icon.png")
			if Postoffice::Person.where(email: self.email).count > 0
				[banner_image_attachment]
			else
				[banner_image_attachment, app_store_icon]
			end
		end

	end

end
