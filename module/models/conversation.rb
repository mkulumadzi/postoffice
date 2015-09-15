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

		def most_recent_mail_received_by_person person
			self.mail.where(status: "DELIVERED", :correspondents.elem_match => { :_type => "Postoffice::ToPerson", :person_id => person.id} ).order_by(date_delivered: "desc").first
		end

		def most_recent_mail_sent_by_person person
			self.mail.where(:correspondents.elem_match => { :_type => "Postoffice::FromPerson", :person_id => person.id} ).order_by(date_sent: "desc").first
		end

		def person_sent_most_recent_mail? person
			last_mail_received = self.most_recent_mail_received_by_person(person)
			last_mail_sent = self.most_recent_mail_sent_by_person(person)

			if last_mail_sent && last_mail_received && last_mail_sent.date_sent.to_i > last_mail_received.date_delivered.to_i
				return true
			elsif last_mail_sent && last_mail_received && last_mail_sent.date_sent.to_i <= last_mail_received.date_delivered.to_i
				return false
			elsif last_mail_sent
				return true
			elsif last_mail_received
				return false
			else
				return false
			end
		end

		def metadata_for_person person
			Hash(
				people: self.people,
				emails: self.emails,
				updated_at: self.mail_for_person(person).order_by(updated_at: "desc").first[:updated_at],
				num_unread: self.unread_mail_for_person(person).count,
				num_undelivered: self.undelivered_mail_from_person(person).count,
				person_sent_most_recent_mail: self.person_sent_most_recent_mail?(person)
			)
		end

	end

end
