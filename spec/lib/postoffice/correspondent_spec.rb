require_relative '../../spec_helper'

describe Postoffice::Correspondent do

  describe 'create a recipient' do

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

	end

	describe Postoffice::Email do

	  before do
			@mail1 = create(:mail, correspondents: [build(:email, email:"test@test.com")])
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

	end

end
