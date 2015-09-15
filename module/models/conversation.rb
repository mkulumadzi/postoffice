module Postoffice
	class Conversation
		include Mongoid::Document
		include Mongoid::Timestamps

    field :hex_hash, type: String
    field :people, type: Array
    field :emails, type: Array

    index({ hex_hash: 1 }, { unique: true })

		def mail
			query = self.initialize_conversation_mail_query
			query = self.add_people_to_conversation_mail_query query
			query = self.add_emails_to_conversation_mail_query query
			query
		end

		def initialize_conversation_mail_query
			num_correspondents = self.num_correspondents
			Postoffice::Mail.where("correspondents.#{num_correspondents}" => { "$exists" => false })
		end

		def num_correspondents
			num_correspondents = self.people.count
			if emails != nil then num_correspondents += self.emails.count end
			num_correspondents
		end

		def add_people_to_conversation_mail_query query
			query.all_in("correspondents.person_id" => self.people)
		end

		def add_emails_to_conversation_mail_query query
			if self.emails != nil
				query.all_in("correspondents.email" => self.emails)
			else
				query
			end
		end

		def mail_for_person person
			self.mail.or({status: "DELIVERED"},{:correspondents.elem_match => {:_type => "Postoffice::FromPerson", :person_id => person.id}})
		end

		def unread_mail_for_person person
			self.mail.where(status: "DELIVERED", :correspondents.elem_match => { :_type => "Postoffice::ToPerson", :person_id => person.id, :status => {"$ne" => "READ"}})
		end

		def undelivered_mail_from_person person
			self.mail.where(status: "SENT", :correspondents.elem_match => {:_type => "Postoffice::FromPerson", :person_id => person.id})
		end

		# def most_recent_mail_for_person person
		# 	self.mail_for_person(person).order_by(:)
		# end

	end

end
