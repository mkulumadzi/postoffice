require_relative '../../spec_helper'

describe Postoffice::Conversation do

  before do

    @person1 = create(:person, username: random_username)
    @person2 = create(:person, username: random_username)
    @person3 = create(:person, username: random_username)

    @mail1 = create(:mail, correspondents: [build(:from_person, person_id: @person1.id), build(:to_person, person_id: @person2.id), build(:email, email: "test@test.com"), build(:email, email: "test2@test.com")])

    @conversation = Postoffice::Conversation.new(@mail1.conversation)
    @conversation.save

  end

  describe 'create conversation' do

    it 'must store a unique hex hash of the conversation' do
      @conversation.hex_hash.must_be_instance_of String
    end

    it 'must store an array of the people' do
      @conversation.people.must_be_instance_of Array
    end

    it 'must store an array of the emails' do
      @conversation.emails.must_be_instance_of Array
    end

    it 'must have a unique index on the hex hash, preventing the dubplicate conversation entries' do
      assert_raises Mongo::Error::OperationFailure do
        duplicate_mail = Postoffice::Conversation.new(@mail1.conversation)
        duplicate_mail.save
      end
    end

  end

  describe 'mail' do

		describe 'initialize conversation mail query' do

			before do
				@query = @conversation.initialize_conversation_mail_query
			end

      describe 'number of correspondents' do

        it 'must return the total number of correspondents, including people and emails' do
          @conversation.num_correspondents.must_equal (@conversation.people.count + @conversation.emails.count)
        end

        it 'must return the total number of people if there are no emails' do
          another_mail = create(:mail, correspondents: [build(:from_person, person_id: @person1.id), build(:to_person, person_id: @person2.id)])
          conversation = Postoffice::Conversation.new(another_mail.conversation)
          conversation.save

          conversation.num_correspondents.must_equal conversation.people.count
        end

      end

			it 'must return a Mongoid Criteria' do
				@query.must_be_instance_of Mongoid::Criteria
			end

			it 'must specify the maximum number of correspondents' do
				@query.selector.must_equal Hash["correspondents.#{@conversation.num_correspondents}", Hash["$exists", false]]
			end

		end

		describe 'add people to conversation query' do

			before do
				@original_query = @conversation.initialize_conversation_mail_query
				@new_query = @conversation.add_people_to_conversation_mail_query @original_query
			end

			it 'must append an all_in selector for the correspondent person_ids' do
				@new_query.selector["correspondents.person_id"]["$all"].must_be_instance_of Array
			end

      it 'must add all of the person ids to this selector' do
        @new_query.selector["correspondents.person_id"]["$all"].must_equal @conversation.people
      end

			it 'must append this query to the original query' do
				num_correspondents = @conversation.num_correspondents
				@new_query.selector.keys.must_equal ["correspondents.#{num_correspondents}", "correspondents.person_id"]
			end

		end

		describe 'add emails to conversation query' do

			before do
				@original_query = @conversation.initialize_conversation_mail_query
				@people_query = @conversation.add_people_to_conversation_mail_query @original_query
				@email_query = @conversation.add_emails_to_conversation_mail_query @people_query
			end

			it 'must append an all_in selector for the correspondent emails' do
				@email_query.selector["correspondents.email"]["$all"].must_be_instance_of Array
			end

			it 'must include all emails' do
				expected_array = ["test@test.com", "test2@test.com"]
				(@email_query.selector["correspondents.email"]["$all"] - expected_array).must_equal []
			end

			it 'must append this query to the original query' do
				num_correspondents = @conversation.num_correspondents
				@email_query.selector.keys.must_equal ["correspondents.#{num_correspondents}", "correspondents.person_id", "correspondents.email"]
			end

			describe 'conversation with no emails' do

				before do
					another_mail = create(:mail, correspondents: [build(:from_person, person_id: @person1.id), build(:to_person, person_id: @person3.id), build(:to_person, person_id: @person2.id)])

          @no_email_conversation = Postoffice::Conversation.new(another_mail.conversation)

					@no_email_query = @no_email_conversation.initialize_conversation_mail_query
					@no_email_query = @no_email_conversation.add_people_to_conversation_mail_query @no_email_query
					@no_email_query = @no_email_conversation.add_emails_to_conversation_mail_query @no_email_query
				end

				it 'must not add a selector for emails' do
					num_correspondents = @no_email_conversation.num_correspondents
					@no_email_query.selector.keys.must_equal ["correspondents.#{num_correspondents}", "correspondents.person_id"]
				end

			end

		end

		describe 'conversation mail query' do

			before do
				@query = @conversation.mail
			end

			it 'must have all of the selectors' do
				num_correspondents = @conversation.num_correspondents
				@query.selector.keys.must_equal ["correspondents.#{num_correspondents}", "correspondents.person_id", "correspondents.email"]
			end

			it 'must return the mail when it is evaluated' do
				@query.to_a.include?(@mail1).must_equal true
			end

		end

  end

  describe 'conversation mail query for a person' do

    before do
      @conversation_mail_for_person = @conversation.mail_for_person @person1
    end

    describe 'the OR selector that is added' do

      before do
        @or_selector = @conversation_mail_for_person.selector["$or"]
      end

      it 'must specify in its first element that the status can be DELIVERD' do
        @or_selector[0]["status"].must_equal "DELIVERED"
      end

      it 'must specify that the mail can also be from the person' do
        @or_selector[1]["correspondents"]["$elemMatch"].must_equal Hash(:_type => "Postoffice::FromPerson", :person_id => @person1.id)
      end

    end

    describe 'expected results for the query' do

      before do

        @mail2 = create(:mail, correspondents: [build(:from_person, person_id: @person2.id), build(:to_person, person_id: @person1.id), build(:email, email: "test@test.com"), build(:email, email: "test2@test.com")])
        @mail2.mail_it
        @mail2.deliver

        @mail3 = create(:mail, correspondents: [build(:from_person, person_id: @person2.id), build(:to_person, person_id: @person1.id), build(:email, email: "test@test.com"), build(:email, email: "test2@test.com")])
        @mail3.mail_it

        @mail4 = create(:mail, correspondents: [build(:from_person, person_id: @person1.id), build(:to_person, person_id: @person2.id), build(:email, email: "test@test.com"), build(:email, email: "test2@test.com"), build(:email, email: "test3@test.com")])
        @mail4.mail_it

        @conversation = Postoffice::Conversation.find_by(hex_hash: @mail1.conversation[:hex_hash])
        @mail_for_person_from_conversation = @conversation.mail_for_person(@person1).to_a

      end

      it 'must include mail from the conversation that was sent by the person' do
        @mail_for_person_from_conversation.include?(@mail1).must_equal true
      end

      it 'must include mail from the conversation that was sent to the person and has been DELIVERED' do
        @mail_for_person_from_conversation.include?(@mail2).must_equal true
      end

      it 'must not include mail from the conversation that was not sent by the person and has not been DELIVERED' do
        @mail_for_person_from_conversation.include?(@mail3).must_equal false
      end

      it 'must not include mail that is not part of the conversation' do
        @mail_for_person_from_conversation.include?(@mail4).must_equal false
      end

    end

    describe 'unread mail for a person' do

      before do
        @unread_mail = @conversation.unread_mail_for_person @person2
      end

      it 'must return a Mongoid Criteria' do
        @unread_mail.must_be_instance_of Mongoid::Criteria
      end

      it 'must not return mail that has been read by the person' do
        @mail1.read_by @person2
        @unread_mail.to_a.include?(@mail1).must_equal false
      end

      it 'must return mail that has not been read by the person' do
        include_mail = create(:mail, correspondents: [build(:from_person, person_id: @person1.id), build(:to_person, person_id: @person2.id), build(:email, email: "test@test.com"), build(:email, email: "test2@test.com")])
        include_mail.mail_it
        include_mail.deliver

        @unread_mail.to_a.include?(include_mail).must_equal true
      end

      it 'must not return mail that has not been delivered yet' do
        not_delivered = create(:mail, correspondents: [build(:from_person, person_id: @person1.id), build(:to_person, person_id: @person2.id), build(:email, email: "test@test.com"), build(:email, email: "test2@test.com")])
        not_delivered.mail_it

        @unread_mail.to_a.include?(not_delivered).must_equal false
      end

      it 'must not return mail that the person sent' do
        sent_by_the_person = create(:mail, correspondents: [build(:from_person, person_id: @person2.id), build(:to_person, person_id: @person1.id), build(:email, email: "test@test.com"), build(:email, email: "test2@test.com")])
        sent_by_the_person.mail_it
        sent_by_the_person.deliver

        @unread_mail.to_a.include?(sent_by_the_person).must_equal false
      end

    end

    describe 'undelivered mail from a person' do

      before do
        @undelivered_mail = @conversation.undelivered_mail_from_person(@person1)
      end

      it 'must return a Mongoid Criteria' do
        @undelivered_mail.must_be_instance_of Mongoid::Criteria
      end

      it 'must return mail that was sent by the person and has not been delivered yet' do
        include_mail = create(:mail, correspondents: [build(:from_person, person_id: @person1.id), build(:to_person, person_id: @person2.id), build(:email, email: "test@test.com"), build(:email, email: "test2@test.com")])
        include_mail.mail_it

        @undelivered_mail.to_a.include?(include_mail).must_equal true
      end

      it 'must not return mail that was sent by the person and has been delivered' do
        exclude_mail = create(:mail, correspondents: [build(:from_person, person_id: @person1.id), build(:to_person, person_id: @person2.id), build(:email, email: "test@test.com"), build(:email, email: "test2@test.com")])
        exclude_mail.mail_it
        exclude_mail.deliver

        @undelivered_mail.to_a.include?(exclude_mail).must_equal false
      end

      it 'must not return mail that was sent by another person' do
        exclude_mail = create(:mail, correspondents: [build(:from_person, person_id: @person2.id), build(:to_person, person_id: @person1.id), build(:email, email: "test@test.com"), build(:email, email: "test2@test.com")])
        exclude_mail.mail_it

        @undelivered_mail.to_a.include?(exclude_mail).must_equal false
      end

    end

    describe 'most recent mail received by person' do

      before do
        @earlier_mail = create(:mail, correspondents: [build(:from_person, person_id: @person2.id), build(:to_person, person_id: @person1.id), build(:email, email: "test@test.com"), build(:email, email: "test2@test.com")])
        @earlier_mail.mail_it
        @earlier_mail.deliver

        @later_mail = create(:mail, correspondents: [build(:from_person, person_id: @person2.id), build(:to_person, person_id: @person1.id), build(:email, email: "test@test.com"), build(:email, email: "test2@test.com")])
        @later_mail.mail_it
        @later_mail.deliver
        @later_mail.date_delivered = Time.now + 4.minutes
        @later_mail.save
      end

      it 'must return the most recent mail received by the person, based on the date it was delivered' do
        @conversation.most_recent_mail_received_by_person(@person1).must_equal @later_mail
      end

    end

    describe 'most recent mail sent by person' do

      before do
        @earlier_mail = create(:mail, correspondents: [build(:from_person, person_id: @person2.id), build(:to_person, person_id: @person1.id), build(:email, email: "test@test.com"), build(:email, email: "test2@test.com")])
        @earlier_mail.mail_it

        @later_mail = create(:mail, correspondents: [build(:from_person, person_id: @person2.id), build(:to_person, person_id: @person1.id), build(:email, email: "test@test.com"), build(:email, email: "test2@test.com")])
        @later_mail.mail_it
        @later_mail.date_sent = Time.now + 4.minutes
        @later_mail.save
      end

      it 'must return the most recent mail sent by the person, based on the date it was sent' do
        @conversation.most_recent_mail_sent_by_person(@person2).must_equal @later_mail
      end

    end

    describe 'person sent most recent mail?' do

      before do
        @sent_mail = create(:mail, correspondents: [build(:from_person, person_id: @person2.id), build(:to_person, person_id: @person1.id), build(:email, email: "test@test.com"), build(:email, email: "test2@test.com")])
        @sent_mail.mail_it

        @received_mail = create(:mail, correspondents: [build(:from_person, person_id: @person1.id), build(:to_person, person_id: @person2.id), build(:email, email: "test@test.com"), build(:email, email: "test2@test.com")])
        @received_mail.mail_it
        @received_mail.deliver
      end

      it 'must return true if the person sent a mail more recently than they received a mail' do
        @sent_mail.date_sent = Time.now + 5.minutes
        @sent_mail.save

        @conversation.person_sent_most_recent_mail?(@person2).must_equal true
      end

      it 'must return false if the person received a mail more recently than they sent one' do
        @received_mail.date_delivered = Time.now + 5.minutes
        @received_mail.save

        @conversation.person_sent_most_recent_mail?(@person2).must_equal false
      end

    end

    describe 'conversation metadata for person' do

      # def metadata_for_person person
      #   Hash(
      #     updated_at: self.mail_for_person(person).order_by(updated_at: "desc").first[:updated_at],
      #     num_unread: self.unread_mail_for_person(person).count,
      #     num_undelivered: self.undelivered_mail_for_person(person).count,
      #     person_sent_most_recent_mail: self.person_sent_most_recent_mail?(person)
      #   )
      # end

      before do
        undelivered_1 = create(:mail, correspondents: [build(:from_person, person_id: @person1.id), build(:to_person, person_id: @person2.id), build(:email, email: "test@test.com"), build(:email, email: "test2@test.com")])
        undelivered_1.mail_it

        undelivered_2 = create(:mail, correspondents: [build(:from_person, person_id: @person1.id), build(:to_person, person_id: @person2.id), build(:email, email: "test@test.com"), build(:email, email: "test2@test.com")])
        undelivered_2.mail_it

        unread_1 = create(:mail, correspondents: [build(:from_person, person_id: @person2.id), build(:to_person, person_id: @person1.id), build(:email, email: "test@test.com"), build(:email, email: "test2@test.com")])
        unread_1.mail_it
        unread_1.deliver

        undelivered_1.updated_at = Time.now + 4.minutes
        undelivered_1.date_sent = Time.now + 3.minutes
        undelivered_1.save
        @last_update = undelivered_1.updated_at

        @metadata = @conversation.metadata_for_person @person1
      end

      it 'must list the people' do
        @metadata[:people].must_equal @conversation.people
      end

      it 'must list the emails' do
        @metadata[:emails].must_equal @conversation.emails
      end

      it 'must give the date and time that the last mail was updated' do
        @metadata[:updated_at].to_i.must_equal @last_update.to_i
      end

      it 'must give the nubmer of unread mail' do
        @metadata[:num_unread].must_equal 1
      end

      it 'must give the number of undelivered mail' do
        @metadata[:num_undelivered].must_equal 2
      end

      it 'must indicate whether or not the last mail was sent by the person' do
        @metadata[:person_sent_most_recent_mail].must_equal true
      end

    end

	end

end
