module Postoffice
	class Contact
		include Mongoid::Document
		include Mongoid::Timestamps

    field :person_id, type: String
    field :contact_person_id, type: String
    field :in_address_book, type: Boolean
    field :is_penpal, type: Boolean

		index({ person_id: 1, contact_person_id: 1}, { unique: true })

	end
end
