require_relative '../../spec_helper'

describe Postoffice::MigrationService do

  before do
    @person1 = create(:person, username: random_username)
    @person2 = create(:person, username: random_username)
    image1 = File.open('spec/resources/image1.jpg')
    @uid = Dragonfly.app.store(image1.read, 'name' => 'image1.jpg')
    image1.close

    @migrate_mail = Postoffice::Mail.create(from: @person1.username, to: @person2.username, content: "Migrate this mtf", scheduled_to_arrive: Time.now, status: "READ", image_uid: @uid, thumbnail_uid: @uid)

    @okay_mail = create(:mail, attachments:[build(:note, content: "Okay here")], correspondents: [build(:from_person, person_id: @person1.id), build(:to_person, person_id: @person2.id)])
    @okay_mail.mail_it
    @okay_mail.deliver
  end

  describe 'migrate to ToPerson' do

    describe 'mail with to and no correspondent' do

      before do
        @result = Postoffice::MigrationService.mail_with_to_and_no_correspondent.to_a
      end

      it 'must return mail with to and no ToPerson' do
        @result.include?(@migrate_mail).must_equal true
      end

      it 'must not reutrn mail with a ToPerson' do
        @result.include?(@okay_mail).must_equal false
      end

    end

    describe 'migrate the mail' do

      before do
        Postoffice::MigrationService.migrate_to_ToPerson
        @migrated_mail = Postoffice::Mail.find(@migrate_mail.id)
      end

      it 'must have added the ToPerson' do
        @migrated_mail.correspondents.where(_type: "Postoffice::ToPerson").count.must_equal 1
      end

      it 'must have status of DELIVERED' do
        @migrated_mail.status.must_equal "DELIVERED"
      end

      it 'must have to be nil' do
        @migrated_mail.to.must_equal nil
      end

      describe 'ToPerson' do

        before do
          @to_person = @migrated_mail.correspondents[0]
        end

        it 'must have a status of READ' do
          @to_person.status.must_equal "READ"
        end

        it 'must have attempted_to_notify as true' do
          @to_person.attempted_to_notify.must_equal true
        end

        it 'must have the date it was read' do
          @to_person.date_read.must_be_instance_of DateTime
        end

      end

      describe 'mail has not been read' do

        before do
          @unread_mail = Postoffice::Mail.create(from: @person1.username, to: @person2.username, content: "Migrate this mtf", scheduled_to_arrive: Time.now, status: "DELIVERED", image_uid: @uid, thumbnail_uid: @uid)
          Postoffice::MigrationService.migrate_to_ToPerson
          @migrated_mail = Postoffice::Mail.find(@unread_mail.id)
        end

        it 'must still have status of DELIVERED' do
          @migrated_mail.status.must_equal "DELIVERED"
        end

        it 'must have a status of nil on the correspondent' do
          @migrated_mail.correspondents[0].status.must_equal nil
        end

        it 'must not have a date read on the correspondent' do
          @migrated_mail.correspondents[0].date_read.must_equal nil
        end

      end

    end

  end

  describe 'migrate to FromPerson' do

    describe 'mail with from and no correspondent' do

      before do
        @result = Postoffice::MigrationService.mail_with_from_and_no_correspondent.to_a
      end

      it 'must return mail with from and no FromPerson' do
        @result.include?(@migrate_mail).must_equal true
      end

      it 'must not reutrn mail with a FromPerson' do
        @result.include?(@okay_mail).must_equal false
      end

    end

    describe 'migrate the mail' do

      before do
        Postoffice::MigrationService.migrate_to_FromPerson
        @migrated_mail = Postoffice::Mail.find(@migrate_mail.id)
      end

      it 'must have added the FromPerson' do
        @migrated_mail.correspondents.where(_type: "Postoffice::FromPerson").count.must_equal 1
      end

      it 'must have from be nil' do
        @migrated_mail.from.must_equal nil
      end

    end

  end

  describe 'migrate to date_delivered' do

    describe 'mail with no date delivered' do

      before do
        @delivered_mail = Postoffice::Mail.create(from: @person1.username, to: @person2.username, content: "Migrate this mtf", scheduled_to_arrive: Time.now, status: "DELIVERED", image_uid: @uid, thumbnail_uid: @uid)
        @mail = Postoffice::MigrationService.mail_with_no_date_delivered.to_a
      end

      it 'must return mail with no date delivered and status of "READ"' do
        @mail.include?(@migrate_mail).must_equal true
      end

      it 'must return mail with no date delivered and status of "DELIVERED"' do
        @mail.include?(@delivered_mail).must_equal true
      end

      it 'must not include mail that has a date_delivered' do
        @mail.include?(@okay_mail).must_equal false
      end

    end

    describe 'migrate the mail' do

      before do
        Postoffice::MigrationService.migrate_to_date_delivered
        @migrated_mail = Postoffice::Mail.find(@migrate_mail.id)
      end

      it 'must have its date_delivered set to the scheduled_to_arrive date' do
        @migrated_mail.date_delivered.to_i.must_equal @migrated_mail.scheduled_to_arrive.to_i
      end

    end

  end

  describe 'migrate to date_sent' do

    describe 'mail with no date sent' do

      before do
        @sent_mail = Postoffice::Mail.create(from: @person1.username, to: @person2.username, content: "Migrate this mtf", scheduled_to_arrive: Time.now, status: "SENT", image_uid: @uid, thumbnail_uid: @uid)
        @mail = Postoffice::MigrationService.mail_with_no_date_sent.to_a
      end

      it 'must return mail with no date delivered and status of "READ"' do
        @mail.include?(@migrate_mail).must_equal true
      end

      it 'must return mail with no date delivered and status of "SENT"' do
        @mail.include?(@sent_mail).must_equal true
      end

      it 'must not include mail that has a date_delivered' do
        @mail.include?(@okay_mail).must_equal false
      end

    end

    describe 'migrate the mail' do

      before do
        Postoffice::MigrationService.migrate_to_date_sent
        @migrated_mail = Postoffice::Mail.find(@migrate_mail.id)
      end

      it 'must have its date_sent set to the created_at date' do
        @migrated_mail.date_sent.to_i.must_equal @migrated_mail.created_at.to_i
      end

    end

  end

  describe 'migrate to Note' do

    describe 'mail with content and no note' do

      before do
        @result = Postoffice::MigrationService.mail_with_content_and_no_note.to_a
      end

      it 'must return mail with content and no Note' do
        @result.include?(@migrate_mail).must_equal true
      end

      it 'must not reutrn mail with a Note' do
        @result.include?(@okay_mail).must_equal false
      end

    end

    describe 'migrate the mail' do

      before do
        Postoffice::MigrationService.migrate_to_note
        @migrated_mail = Postoffice::Mail.find(@migrate_mail.id)
      end

      it 'must have added the Note' do
        @migrated_mail.attachments.where(_type: "Postoffice::Note").count.must_equal 1
      end

      it 'must have set the content on the note' do
        @migrated_mail.attachments.where(_type: "Postoffice::Note")[0].content.must_equal @migrate_mail.content
      end

      it 'must have content be nil' do
        @migrated_mail.content.must_equal nil
      end

    end

    describe 'migrate to ImageAttachment' do

      describe 'mail with image_uid and no ImageAttachment' do

        before do
          @result = Postoffice::MigrationService.mail_with_image_uid_and_no_attachment
        end

        it 'must return mail to migrate' do
          @result.include?(@migrate_mail).must_equal true
        end

        it 'must not reutrn mail with an image_attachment' do
          @result.include?(@okay_mail).must_equal false
        end

      end

      describe 'migrate the mail' do

        before do
          Postoffice::MigrationService.migrate_to_image_attachment
          @migrated_mail = Postoffice::Mail.find(@migrate_mail.id)
        end

        it 'must have added the ImageAttachment' do
          @migrated_mail.attachments.where(_type: "Postoffice::ImageAttachment").count.must_equal 1
        end

        it 'must have set the image_uid on the ImageAttachment' do
          @migrated_mail.attachments.where(_type: "Postoffice::ImageAttachment")[0].image_uid.must_equal @migrate_mail.image_uid
        end

        it 'must have image_uid be nil' do
          @migrated_mail.image_uid.must_equal nil
        end

        it 'must have thumbnail_uid be nil' do
          @migrated_mail.thumbnail_uid.must_equal nil
        end

      end

    end

    describe 'run all of the migrations' do

      before do
        Postoffice::MigrationService.migrate_to_correspondents_and_attachments
        @migrated_mail = Postoffice::Mail.find(@migrate_mail.id)
      end

      it 'must have added the ToPerson' do
        @migrated_mail.correspondents.where(_type: "Postoffice::ToPerson").count.must_equal 1
      end

      it 'must have added the FromPerson' do
        @migrated_mail.correspondents.where(_type: "Postoffice::FromPerson").count.must_equal 1
      end

      it 'must have added the date_delivered' do
        @migrated_mail.date_delivered.must_be_instance_of DateTime
      end

      it 'must have added the date_sent' do
        @migrated_mail.date_sent.must_be_instance_of DateTime
      end

      it 'must have added the note' do
        @migrated_mail.attachments.where(_type: "Postoffice::Note").count.must_equal 1
      end

      it 'must have added the ImageAttachment' do
        @migrated_mail.attachments.where(_type: "Postoffice::ImageAttachment").count.must_equal 1
      end

      it 'must have created the conversation' do
        Postoffice::Conversation.where(hex_hash: @migrated_mail.conversation_hash[:hex_hash]).count.must_equal 1
      end

    end

  end

end
