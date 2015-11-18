require_relative '../../spec_helper'

describe Postoffice::Correspondent do

  describe 'create a correspondent' do

    before do
			@mail1 = create(:mail)
      @correspondent = Postoffice::Correspondent.new
      @mail1.correspondents << @correspondent
    end

    it 'must have an object id' do
      @correspondent.id.must_be_instance_of BSON::ObjectId
    end

    it 'must indicate the time it was created' do
      @correspondent.created_at.must_be_instance_of Time
    end

    it 'must indicate the time it was updated' do
      @correspondent.updated_at.must_be_instance_of Time
    end

    it 'must be able to be retrieved from the mail' do
      @mail1.correspondents.include?(@correspondent).must_equal true
    end

		it 'must be able to retrieve its parent mail' do
			@correspondent.mail.must_equal @mail1
		end

  end

	describe Postoffice::FromPerson do

		before do
	    @person1 = create(:person, username: random_username)
	    @mail1 = create(:mail, correspondents: [build(:from_person, person_id: @person1.id)])
			@from_person = @mail1.correspondents.where(_type: "Postoffice::FromPerson")[0]
	  end

		it 'must store the person_id' do
			@from_person.person_id.must_equal @person1.id
		end

	end


	describe Postoffice::ToPerson do

	  before do
			@person1 = create(:person, username: random_username)
			@mail1 = create(:mail, correspondents: [build(:to_person, person_id: @person1.id)])
			@to_person = @mail1.correspondents.where(_type: "Postoffice::ToPerson")[0]
	  end

		it 'must store the person_id' do
			@to_person.person_id.must_equal @person1.id
		end

		it 'must be able to store the fact that a the app attempted to send a notification to the person' do
			@to_person.attempted_to_notify = true
			@to_person.save
			@to_person.attempted_to_notify.must_equal true
		end

		describe 'person reads mail' do

      describe 'read mail' do

  			before do
  				@to_person.read
  			end

  			it 'must set the status to READ' do
  				@to_person.status.must_equal "READ"
  			end

  			it 'must set the date it was read to the current date and time' do
  				@to_person.date_read.to_i.must_equal Time.now.to_i
  			end

      end

      describe 'update parent record' do

        before do
          sleep 1
          @to_person.read
        end

        it 'must have saved the parent mail as well, giving it the current date and time for its updated_at field' do
          @mail1.updated_at.to_i.must_equal Time.now.to_i
        end

      end

	  end

	end

	describe Postoffice::Email do

	  before do
      @person = create(:person, username: random_username)
			@mail1 = create(:mail, correspondents: [build(:from_person, person_id: @person.id),build(:email, email:"test@test.com")])
      @mail1.mail_it
      @mail1.deliver
			@email = @mail1.correspondents.where(_type: "Postoffice::Email")[0]
	  end

		it 'must store the email' do
			@email.email.must_equal "test@test.com"
		end

		it 'must be able to store the date and time that the email was sent' do
			@email.attempted_to_send = true
			@email.save
			@email.attempted_to_send.must_equal true
		end

    describe 'template' do

      it 'must return the correct template for an existing user' do
        person = create(:person, email: "#{random_username}@test.com", username: random_username)
        mail = create(:mail, correspondents: [build(:from_person, person_id: @person.id), build(:email, email: person.email)])
        email_correspondent = mail.correspondents.where(_type: "Postoffice::Email")[0]
        email_correspondent.template.must_equal 'resources/existing_user_email_template.html'
      end

      it 'must return the new recipient template for a new email address' do
        email_address = "#{random_username}@test.com"
        mail = create(:mail, correspondents: [build(:from_person, person_id: @person.id), build(:email, email: email_address)])
        correspondent = mail.correspondents.where(_type: "Postoffice::Email")[0]
        correspondent.template.must_equal 'resources/new_recipient_email_template.html'
      end

      describe 'repeat recipient' do

        before do
          email_address = "#{random_username}@test.com"
          @mail1 = create(:mail, correspondents: [build(:from_person, person_id: @person.id), build(:email, email: email_address)])
          @mail2 = create(:mail, correspondents: [build(:from_person, person_id: @person.id), build(:email, email: email_address)])

          @first_correspondent = @mail1.correspondents.where(_type: "Postoffice::Email")[0]
        end

        it 'must return the new recipient template if the address has not been emailed yet' do
          @first_correspondent.template.must_equal 'resources/new_recipient_email_template.html'
        end

        it 'must return the repeat template for a repeat recipient' do
          @first_correspondent.attempted_to_send = true
          @mail1.save

          second_correspondent = @mail2.correspondents.where(_type: "Postoffice::Email")[0]
          second_correspondent.template.must_equal 'resources/repeat_recipient_email_template.html'
        end

      end

    end

    describe 'image attachments' do

      it 'must only return the banner image if the correspondent is an existing user' do
        person = create(:person, email: "#{random_username}@test.com", username: random_username)
        mail = create(:mail, correspondents: [build(:from_person, person_id: @person.id), build(:email, email: person.email)])
        email_correspondent = mail.correspondents.where(_type: "Postoffice::Email")[0]

        email_correspondent.image_attachments.must_equal [Postoffice::EmailService.image_email_attachment("resources/slowpost_banner.png")]
      end

      it 'must return both the banner image and the app store icon if the correspondent is not an existing user' do
        email_address = "#{random_username}@test.com"
        mail = create(:mail, correspondents: [build(:from_person, person_id: @person.id), build(:email, email: email_address)])
        correspondent = mail.correspondents.where(_type: "Postoffice::Email")[0]

        correspondent.image_attachments.must_equal [Postoffice::EmailService.image_email_attachment("resources/slowpost_banner.png"), Postoffice::EmailService.image_email_attachment("resources/app_store_icon.png")]
      end

    end

	end

end
