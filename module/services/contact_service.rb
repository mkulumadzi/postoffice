module Postoffice

  class ContactService

    def self.add_or_update_penpal_contact person, contact
      contact = self.get_contact person, contact
      if contact == nil
        self.add_penpal_contact person, contact
      elsif contact.is_penpal == false
        contact.is_penpal == true
        contact.save
      end
    end

    def self.add_or_update_address_book_contact person, contact
      contact = self.get_contact person, contact
      if contact == nil
        self.add_address_book_contact person, contact
      elsif contact.in_address_book == false
        contact.in_address_book == true
        contact.save
      end
    end

    def self.get_contact person, contact
      begin
        Postoffice::Contact.find_by(person_id: person.id.to_s, contact_person_id: contact.id.to_s)
      rescue Mongoid::Errors::DocumentNotFound
        nil
      end
    end

    def self.add_penpal_contact person, contact
      Postoffice::Contact.create!({
          person_id: person.id,
          contact_person_id: contact_person_id,
          is_penpal: true,
          in_address_book: false
        })
    end

    def self.add_address_book_contact person, contact
      Postoffice::Contact.create!({
          person_id: person.id,
          contact_person_id: contact_person_id,
          is_penpal: false,
          in_address_book: true
        })
    end

  end

end
