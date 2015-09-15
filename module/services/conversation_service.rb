module Postoffice

  class ConversationService

    # Viw a list of the conversations a person has had, and include data such as
    ## The number of unread messages for the person
    ## The number of undelivered mail for the person
    ## The date of the most recent mail in the conversation (that the person is supposed to know about)

    def self.get_conversation_metadata params
      person = Postoffice::Person.find(params[:person_id])
      query_proc = self.proc_for_conversation_metadata_query
      conversations = self.conversation_query(query_proc, params, person).to_a
      self.get_conversation_metadata_for_person conversation, person
    end

    def self.conversation_query query_proc, params, person
      query = conversation_query_proc.call(person)
      query = Postoffice::AppService.add_updated_since_to_query query, params
    end

    def self.proc_for_conversation_metadata_query
      Proc.new { |person| Postoffice::Conversation.where(people: person.id) }
    end

    def self.get_conversation_metadata_for_person conversations, person
      conversation_metadata = []
      conversations.each do |conversation|
          conversation_metadata << conversation.metadata_for_person(person)
      end

      conversation_metadata
    end

    def self.conversation_mail params
      conversation = Postoffice::Conversation.find(params[:conversation_id])
      person = Postoffice::Person.find(params[:person_id])
      query_proc = self.fproc_for_conversation_mail
      self.conversation_query(query_proc, params, person).to_a
    end

    def self.proc_for_conversation_mail
      Proc.new { |person| conversation.mail_for_person(person) }
    end

  end

end
