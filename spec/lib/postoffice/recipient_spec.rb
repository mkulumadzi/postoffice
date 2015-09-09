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

    it 'must indicate the time it was update' do
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
      @slowpost_recipient = Postoffice::SlowpostRecipient.new(person: @person2)
      @mail1.recipients << @slowpost_recipient
    end

    it 'must store the relationship for who the mail is to' do
      @slowpost_recipient.person.must_equal @person2
    end

    it 'must be able to be retrieved from the mail' do
      @mail1.recipients.include?(@slowpost_recipient).must_equal true
    end

    it 'must be able to store the date and time that the notification was sent' do
      @slowpost_recipient.notification_sent = Time.now
      @slowpost_recipient.save
      @slowpost_recipient.notification_sent.must_be_instance_of DateTime
    end

    it 'must be able to store the status' do
      @slowpost_recipient.status = "READ"
      @slowpost_recipient.save
      @slowpost_recipient.status.must_equal "READ"
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

    it 'must save the email' do
      @email_recipient.email.must_equal "test@test.com"
    end

    it 'must be able to be retrieved by the mail' do
      @mail1.recipients.include?(@email_recipient).must_equal true
    end

    it 'must be able to store the date and time that the email was sent' do
      @email_recipient.email_sent = Time.now
      @email_recipient.save
      @email_recipient.email_sent.must_be_instance_of DateTime
    end

  end

end
