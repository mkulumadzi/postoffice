require_relative '../../spec_helper'

describe Postoffice::ConversationService do

  before do
    @person1 = create(:person, username: random_username)
    @person2 = create(:person, username: random_username)
    @person3 = create(:person, username: random_username)

    @mail_convo_1_A = create(:mail, correspondents: [build(:from_person, person_id: @person1.id), build(:to_person, person_id: @person2.id), build(:email, email: "test@test.com"), build(:email, email: "test2@test.com")])
    @mail_convo_1_A.mail_it

    @mail_convo_1_B = create(:mail, correspondents: [build(:from_person, person_id: @person2.id), build(:to_person, person_id: @person1.id), build(:email, email: "test@test.com"), build(:email, email: "test2@test.com")])
    @mail_convo_1_B.mail_it
    @mail_convo_1_B.deliver

    @convo_1 = @mail_convo_1_A.conversation

    @mail_convo_2 = create(:mail, correspondents: [build(:from_person, person_id: @person1.id), build(:to_person, person_id: @person2.id), build(:to_person, person_id: @person3.id)])
    @mail_convo_2.mail_it

    @convo_2 = @mail_convo_2.conversation

    @mail_convo_3 = create(:mail, correspondents: [build(:from_person, person_id: @person1.id), build(:to_person, person_id: @person2.id)])
    @mail_convo_3.mail_it

    @convo_3 = @mail_convo_3.conversation

  end

  describe 'get conversation metadata' do

    describe 'query a persons conversations' do

      before do
        @convo_query = Postoffice::ConversationService.query_persons_conversations @person1
      end

      it 'must return a Mongoid Criteria' do
        @convo_query.must_be_instance_of Mongoid::Criteria
      end

      it 'must be able to get all of the conversations a person is a part of' do
        @convo_query.to_a.must_equal [@convo_1, @convo_2, @convo_3]
      end

    end

    describe 'filter conversations by mail for person' do

      it 'must return conversations that include mail for the person' do
        conversation_query = Postoffice::ConversationService.query_persons_conversations @person1
        params = Hash.new
        filtered_conversations = Postoffice::ConversationService.filter_conversations_by_mail_for_person conversation_query, @person1, params
        filtered_conversations.include?(@convo_1).must_equal true
      end

      it 'must return conversations that do not have mail that has been delivered yet, or set by the person' do
        conversation_query = Postoffice::ConversationService.query_persons_conversations @person3
        params = Hash.new
        filtered_conversations = Postoffice::ConversationService.filter_conversations_by_mail_for_person conversation_query, @person3, params
        filtered_conversations.include?(@convo_2).must_equal false
      end

      it 'must only return conversations with recently updated mail, if an updated_at parameter is given' do
        @mail_convo_3.updated_at = Time.now + 5.minutes
        @mail_convo_3.save

        conversation_query = Postoffice::ConversationService.query_persons_conversations @person1
        params = Hash(updated_at: (Time.now + 4.minutes))
        filtered_conversations = Postoffice::ConversationService.filter_conversations_by_mail_for_person conversation_query, @person1, params
        filtered_conversations.must_equal [@convo_3]
      end

    end

    describe 'get conversation metadata for a person' do

      before do
        @conversations = Postoffice::ConversationService.query_persons_conversations(@person1).to_a
        @conversation_metadata = Postoffice::ConversationService.get_conversation_metadata_for_person @conversations, @person1
      end

      it 'must return an array of hashes' do
        @conversation_metadata[0].must_be_instance_of Hash
      end

      it 'must return a hash for each conversation' do
        @conversation_metadata.count.must_equal @conversations.count
      end

      it 'must return the conversation participants' do
        @conversation_metadata[0][:people].must_equal @conversations[0].people
      end

    end

    it 'must return the conversation metadata' do
      params = Hash(id: @person1.id)
      conversation_metadata = Postoffice::ConversationService.get_conversation_metadata params
      conversation_metadata[0].must_equal @convo_1.metadata_for_person(@person1)
    end

  end

  describe 'conversation mail' do

    describe 'proc for converation mail' do

      it 'must return a Proc' do
        Postoffice::ConversationService.proc_for_conversation_mail(@convo_1).must_be_instance_of Proc
      end

      it 'must return the mail for a person when it is called' do
        query = Postoffice::ConversationService.proc_for_conversation_mail @convo_1
        mail = query.call(@person1).to_a
        mail.must_equal [@mail_convo_1_A, @mail_convo_1_B]
      end

    end

    describe 'conversation query' do

      before do
        @query_proc = Postoffice::ConversationService.proc_for_conversation_mail(@convo_1)
      end

      describe 'get all mail for the conversation' do

        before do
          params = Hash.new
          @query = Postoffice::ConversationService.conversation_query @query_proc, params, @person1
        end

        it 'must return a Mongoid Criteria' do
          @query.must_be_instance_of Mongoid::Criteria
        end

        it 'must return all of the mail for the person' do
          @query.to_a.must_equal [@mail_convo_1_A, @mail_convo_1_B]
        end

      end

      describe 'get mail that was updated since a date' do

        before do
          @mail_convo_1_A.updated_at = Time.now + 5.minutes
          @mail_convo_1_A.save
          params = Hash(updated_at: Hash( "$gt" => (Time.now + 4.minutes) ))
          @query = Postoffice::ConversationService.conversation_query @query_proc, params, @person1
        end

        it 'must have added updated_at to the query' do
          @query.selector.keys.include?("updated_at").must_equal true
        end

        it 'must only return mail updated since the date' do
          @query.to_a.must_equal [@mail_convo_1_A]
        end

      end

    end

    it 'must get the mail for the conversation' do
      params = Hash(person_id: @person1.id, conversation_id: @convo_1.id)
      mail = Postoffice::ConversationService.conversation_mail params
      mail.must_equal [@mail_convo_1_A, @mail_convo_1_B]
    end

  end

  describe 'get people from conversations' do

    # def self.people_from_conversations params
    #   person = Postoffice::Person.find(params[:id])
    #   conversation_metadata = self.conversation_metadata params
    #   people_array = self.get_people_from_conversations conversation_metadata
    #   self.get_unique_people_from_conversation_people_list people_array, person
    # end

    before do
      @params = Hash(id: @person1.id.to_s)
      @conversation_metadata = Postoffice::ConversationService.get_conversation_metadata @params
    end

    describe 'collect all people from conversations' do

      before do
        @all_people = Postoffice::ConversationService.collect_all_people_from_conversations @conversation_metadata
      end

      it 'must return an array of people' do
        @all_people[0].must_be_instance_of Postoffice::Person
      end

      it 'must include all people the person has been in conversations with' do
        expected_people = [@person1, @person2, @person3]
        (expected_people - @all_people).count.must_equal 0
      end

    end

    describe 'get unique people from conversation people list' do

      before do
        @people_array = Postoffice::ConversationService.collect_all_people_from_conversations @conversation_metadata
        @unique_people = Postoffice::ConversationService.get_unique_people_from_conversation_people_list @people_array, @person1
      end

      it 'must not include the person' do
        @unique_people.include?(@person1).must_equal false
      end

      it 'must be a unique list of the people the person has communicated with' do
        @unique_people.must_equal [@person2, @person3]
      end

    end

    it 'must return a unique list of people the person has commnicated with' do
      people = Postoffice::ConversationService.people_from_conversations @params
      people.must_equal [@person2, @person3]
    end

  end

  describe 'create conversations for any mail that does not already have them' do

    before do
      @personA = create(:person, username: random_username)
      @personB = create(:person, username: random_username)
      @personC = create(:person, username: random_username)

      @mail_convo_A = create(:mail, correspondents: [build(:from_person, person_id: @personA.id), build(:to_person, person_id: @personB.id)])
      @mail_convo_A.mail_it

      @mail_convo_B = create(:mail, correspondents: [build(:from_person, person_id: @personA.id), build(:to_person, person_id: @personC.id)])
      @mail_convo_B.mail_it

      Postoffice::ConversationService.initialize_conversations_for_all_mail
    end

    it 'must have created the conversations' do
      hex_hashes = [@mail_convo_A.conversation_hash[:hex_hash], @mail_convo_B.conversation_hash[:hex_hash]]
      Postoffice::Conversation.where(hex_hash: {"$in" => hex_hashes}).count.must_equal 2
    end

  end

end
