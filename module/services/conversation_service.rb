module Postoffice

  class ConversationService

    ### Get conversation metadata for a person

    def self.get_conversation_metadata params
      person = Postoffice::Person.find(params[:id])
      conversation_query = self.query_persons_conversations person
      conversations = self.filter_conversations_by_mail_for_person conversation_query, person, params
      conversation_metadata = self.get_conversation_metadata_for_person conversations, person
    end

    def self.query_persons_conversations person
      Postoffice::Conversation.where(people: person.id)
    end

    def self.filter_conversations_by_mail_for_person conversation_query, person, params
      conversations = conversation_query.to_a
      conversations = conversations.select {|c| c.mail_for_person(person).count > 0 }
      if params[:updated_at]
        conversations = conversations.select { |c| c.mail_for_person(person).order_by(updated_at: "desc").first[:updated_at] > params[:updated_at] }
      end
      conversations
    end

    def self.get_conversation_metadata_for_person conversations, person
      conversation_metadata = []
      conversations.each do |conversation|
          conversation_metadata << conversation.metadata_for_person(person)
      end
      conversation_metadata
    end

    ### View mail from a conversation for a person

    def self.conversation_mail params
      conversation = Postoffice::Conversation.find(params[:conversation_id])
      person = Postoffice::Person.find(params[:person_id])
      query_proc = self.proc_for_conversation_mail conversation
      self.conversation_query(query_proc, params, person).to_a
    end

    def self.proc_for_conversation_mail conversation
      Proc.new { |person| conversation.mail_for_person(person) }
    end

    def self.conversation_query query_proc, params, person
      query = query_proc.call(person)
      query = Postoffice::AppService.add_updated_since_to_query query, params
    end

    ### Get a list of people the person has sent mail to or received mail from

    def self.people_from_conversations params
      person = Postoffice::Person.find(params[:id])
      conversation_metadata = self.get_conversation_metadata params
      people_array = self.collect_all_people_from_conversations conversation_metadata
      self.get_unique_people_from_conversation_people_list people_array, person
    end

    def self.collect_all_people_from_conversations conversation_metadata
      people_array = []
      conversation_metadata.each do |conversation|
        conversation[:people].each do |person_id|
          people_array << Postoffice::Person.find(person_id)
        end
      end
      people_array
    end

    def self.get_unique_people_from_conversation_people_list people_array, person
      people_array = people_array.uniq
      people_array.delete(person)
      people_array
    end

    ### Create converesations for any mail that does not already have them
    def self.initialize_conversations_for_all_mail
      mail = Postoffice::Mail.where({})
      mail.each { |mail| mail.conversation }
    end

  end

end
