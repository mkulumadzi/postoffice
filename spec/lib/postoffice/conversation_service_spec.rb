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
    @convo_1 = Postoffice::Conversation.new(@mail_convo_1_A.conversation)
    @convo_1.save

    @mail_convo_2 = create(:mail, correspondents: [build(:from_person, person_id: @person1.id), build(:to_person, person_id: @person2.id), build(:to_person, person_id: @person3.id)])
    @mail_convo_2.mail_it
    @convo_2 = Postoffice::Conversation.new(@mail_convo_2.conversation)
    @convo_2.save

    @mail_convo_3 = create(:mail, correspondents: [build(:from_person, person_id: @person1.id), build(:to_person, person_id: @person2.id)])
    @mail_convo_3.mail_it
    @convo_3 = Postoffice::Conversation.new(@mail_convo_3.conversation)
    @convo_3.save

  end

  describe 'get conversation metadata' do

    # def self.get_conversation_metadata params
    #   person = Postoffice::Person.find(params[:person_id])
    #   query_proc = self.proc_for_conversation_metadata_query
    #   conversation_query = self.query_persons_conversations conversation_query, person, params
    #   conversations = self.filter_conversations_by_mail_for_person person
    #   conversation_metadata = self.get_conversation_metadata_for_person conversations, person
    # end

    describe 'query a persons conversations' do
    # def self.query_persons_conversations person
    #   Postoffice::Conversation.where(people: person.id)
    # end
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

    # def self.filter_conversations_by_mail_for_person conversation_query, person
    #   conversations = conversation_query.to_a
    #   conversations = conversations.select {|c| c.mail_for_person(person).count > 0 }
    #   if params[:updated_at]
    #     conversations = conversations.select { |c| c.mail_for_person(person).order_by(updated_at: "desc").first[:updated_at] > params[:updated_at] }
    #   end
    #   conversations
    # end

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
    # def self.get_conversation_metadata_for_person conversations, person
    #   conversation_metadata = []
    #   conversations.each do |conversation|
    #       conversation_metadata << conversation.metadata_for_person(person)
    #   end
    #   conversation_metadata
    # end

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
  #
  # ### View mail from a conversation for a person
  #

  # def self.conversation_mail params
  #   conversation = Postoffice::Conversation.find(params[:conversation_id])
  #   person = Postoffice::Person.find(params[:person_id])
  #   query_proc = self.fproc_for_conversation_mail
  #   self.conversation_query(query_proc, params, person).to_a
  # end
  #
    describe 'converastion query' do
    # def self.conversation_query query_proc, params, person
    #   query = conversation_query_proc.call(person)
    #   query = Postoffice::AppService.add_updated_since_to_query query, params
    # end
    end

    describe 'proc for converation mail' do
    # def self.proc_for_conversation_mail
    #   Proc.new { |person| conversation.mail_for_person(person) }
    # end
    end

  end


end
