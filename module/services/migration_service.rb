module Postoffice

  class MigrationService

    # Migrating from 'to' to correspondent
    ## Find mil with a username in the to field and no "ToPerson" correspondnet
    ## Find person
    ## Create a new correspondent and add to the mail record
    ## If mail status is READ, set correspondent status to READ and mail status to DELIVERED, and date_read to updated_at
    ## Set attempted_to_notify as true
    ## Set 'to' to null

    def self.mail_with_to_and_no_correspondent
      Postoffice::Mail.where(to: {"$ne" => nil}).ne( :correspondents.elem_match => { _type: "Postoffice::ToPerson"})
    end

    def self.migrate_to_ToPerson
      mail = self.mail_with_to_and_no_correspondent
      mail.each do |mail|

        to_person = Postoffice::Person.find_by(username: mail.to)
        hash = Hash(person_id: to_person.id, attempted_to_notify: true, mail: mail)

        if mail.status == "READ"
          hash[:status] = "READ"
          mail.status = "DELIVERED"
          hash[:date_read] = mail.updated_at
        end

        correspondent = Postoffice::ToPerson.create!(hash)
        mail.to = nil
        mail.save
      end
    end


    # Migrating from 'from' to correspondent
    ## Find mail with a username in the from field and no "FromPerson" correspondent
    ## Find corresponding person
    ## Create a new corresondent and add it to the mail record
    ## Set 'from' to null

    def self.mail_with_from_and_no_correspondent
      Postoffice::Mail.where(from: {"$ne" => nil}).ne( :correspondents.elem_match => { _type: "Postoffice::FromPerson"})
    end

    def self.migrate_to_FromPerson
      mail = self.mail_with_from_and_no_correspondent
      mail.each do |mail|

        from_person = Postoffice::Person.find_by(username: mail.from)
        hash = Hash(person_id: from_person.id, mail: mail)

        correspondent = Postoffice::FromPerson.create!(hash)
        mail.from = nil
        mail.save
      end
    end

    # Adding new date_delivered field
    # Find mail with date_delivered equal to nil and has status of DELIVERED or READ
    # Set date_delivered to scheduled_to_arrive date

    def self.mail_with_no_date_delivered
      Postoffice::Mail.where(date_delivered: nil, status: {"$in" => ["DELIVERED", "READ"]})
    end

    def self.migrate_to_date_delivered
      mail = self.mail_with_no_date_delivered
      mail.each do |mail|
        mail.date_delivered = mail.scheduled_to_arrive
        mail.save
      end
    end

    # Adding new date_sent field
    # Find mail with date_sent equal to nil that has status of SENT, DELIVERED or READ
    # Set date_sent to created_at

    def self.mail_with_no_date_sent
      Postoffice::Mail.where(date_sent: nil, status: {"$in" => ["SENT", "DELIVERED", "READ"]})
    end

    def self.migrate_to_date_sent
      mail = self.mail_with_no_date_sent
      mail.each do |mail|
        mail.date_sent = mail.created_at
        mail.save
      end
    end

    # Migrating from content to note
    ## Find mail with content and no Note
    ## Create a new Note, and set its content to the content
    ## Set content to nil

    def self.mail_with_content_and_no_note
      Postoffice::Mail.where(content: {"$ne" => nil}).ne( :attachments.elem_match => { _type: "Postoffice::Note"})
    end

    def self.migrate_to_note
      mail = self.mail_with_content_and_no_note
      mail.each do |mail|
        hash = Hash(content: mail.content, mail: mail)
        attachment = Postoffice::Note.create!(hash)
        mail.content = nil
        mail.save
      end
    end

    # Migrating from image to ImageAttachment
    # Find mail with image_uid and no ImageAttachment
    # Create new ImageAttachment for mail and add its image_uid
    # Set image_uid on mail equal to nil
    # Set thumbnail_uid on mail equal to nil

    def self.mail_with_image_uid_and_no_attachment
      Postoffice::Mail.where(image_uid: {"$ne" => nil}).ne( :attachments.elem_match => { _type: "Postoffice::ImageAttachment"})
    end

    def self.migrate_to_image_attachment
      mail = self.mail_with_image_uid_and_no_attachment
      mail.each do |mail|
        hash = Hash(image_uid: mail.image_uid, mail: mail)
        attachment = Postoffice::ImageAttachment.create!(hash)
        mail.image_uid = nil
        mail.thumbnail_uid = nil
        mail.save
      end
    end

    # Run the migrations and create new conversations for all mail
    def self.migrate_to_correspondents_and_attachments
      self.migrate_to_ToPerson
      self.migrate_to_FromPerson
      self.migrate_to_date_delivered
      self.migrate_to_date_sent
      self.migrate_to_note
      self.migrate_to_image_attachment
      Postoffice::ConversationService.initialize_conversations_for_all_mail
    end

  end

end
