module Postoffice

  class ContactService

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
          contact_person_id: contact.id,
          is_penpal: true,
          in_address_book: false
        })
    end

    def self.add_address_book_contact person, contact
      Postoffice::Contact.create!({
          person_id: person.id,
          contact_person_id: contact.id,
          is_penpal: false,
          in_address_book: true
        })
    end

    def self.add_or_update_penpal_contact person, contact_person
      contact = self.get_contact person, contact_person
      if contact == nil
        self.add_penpal_contact person, contact_person
      elsif contact.is_penpal
        nil
      else
        contact.is_penpal = true
        contact.save
        contact
      end
    end

    def self.add_or_update_address_book_contact person, contact_person
      contact = self.get_contact person, contact_person
      if contact == nil
        self.add_address_book_contact person, contact_person
      elsif contact.in_address_book
        nil
      else
        contact.in_address_book = true
        contact.save
        contact
      end
    end

  end

end
