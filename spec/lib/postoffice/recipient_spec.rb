require_relative '../../spec_helper'

describe Postoffice::Recipient do

	before do
		@person1 = create(:person, username: random_username)
    @mail1 = create(:mail, from: @person1.username)
	end

  describe 'create a recipient' do

    before do
      @recipient = Postoffice::Recipient.new
      @mail1.recipients << @recipient
    end

    it 'must have an object id' do
      @recipient.id.must_be_instance_of BSON::ObjectId
    end

    it 'must indicate the time it was created' do
      @recipient.created_at.must_be_instance_of Time
    end

    it 'must indicate the time it was updated' do
      @recipient.updated_at.must_be_instance_of Time
    end

    it 'must be able to be retrieved from the mail' do
      @mail1.recipients.include?(@recipient).must_equal true
    end

  end

end

describe Postoffice::SlowpostRecipient do

  before do
    @person1 = create(:person, username: random_username)
    @person2 = create(:person, username: random_username)
    @mail1 = create(:mail, from: @person1.username)
  end

  describe 'create a Slowpost recipient' do

    before do
      @slowpost_recipient = Postoffice::SlowpostRecipient.new(person_id: @person2.id)
      @mail1.recipients << @slowpost_recipient
    end

		it 'must be of type Postoffice::SlowpostRecipient' do
			@slowpost_recipient._type.must_equal "Postoffice::SlowpostRecipient"
		end

    it 'must store the relationship for who the mail is to' do
      @slowpost_recipient.person_id.must_equal @person2.id
    end

		it 'must store the relationshiop of which mail it belongs to' do
			@slowpost_recipient.mail.must_equal @mail1
		end

    it 'must be able to store the date and time that the notification was sent' do
      @slowpost_recipient.attempted_to_notify = true
      @slowpost_recipient.save
      @slowpost_recipient.attempted_to_notify.must_equal true
    end

		describe 'recipient reads mail' do

			before do
				@slowpost_recipient.read
			end

			it 'must set the status to READ' do
				@slowpost_recipient.status.must_equal "READ"
			end

			it 'must set the date it was read to the current date and time' do
				@slowpost_recipient.date_read.to_i.must_equal Time.now.to_i
			end

		end

  end

end

describe Postoffice::EmailRecipient do

  before do
    @person1 = create(:person, username: random_username)
    @mail1 = create(:mail, from: @person1.username)
  end

  describe 'create an email recipient' do

    before do
      @email_recipient = Postoffice::EmailRecipient.new(email: "test@test.com")
      @mail1.recipients << @email_recipient
    end

		it 'must be of type Postoffice::EmailRecipient' do
			@email_recipient._type.must_equal "Postoffice::EmailRecipient"
		end

    it 'must save the email' do
      @email_recipient.email.must_equal "test@test.com"
    end

		it 'must store the mail it belongs to' do
			@email_recipient.mail.must_equal @mail1
		end

    it 'must be able to store the date and time that the email was sent' do
      @email_recipient.attempted_to_send = true
      @email_recipient.save
      @email_recipient.attempted_to_send.must_equal true
    end

  end

end
