module Postoffice

  class ContactService

    def self.get_contacts_for_person person, params
      conversation_people = Postoffice::ConversationService.people_from_conversations person, params
      facebook_friends = self.get_facebook_friends_for_person person
      (conversation_people += facebook_friends).uniq
    end

    def self.get_facebook_friends_for_person person
      friends = []
      if person.facebook_token
        facebook_json = self.get_json_document_of_person_facebook_friends person.facebook_token
        facebook_json ? friends = self.get_people_from_facebook_json(facebook_json) : nil
      end
      friends
    end

    def self.get_json_document_of_person_facebook_friends facebook_token
      begin
        json = JSON.parse(RestClient.get "https://graph.facebook.com/me/friends?access_token=#{facebook_token}")
        json["data"]
      rescue RestClient::BadRequest
        nil
      end
    end

    def self.get_people_from_facebook_json facebook_json
      friends = []
      facebook_json.each do |person_json|
        begin
          friends << Postoffice::Person.find_by(facebook_id: person_json["id"])
        rescue Mongoid::Errors::DocumentNotFound
        end
      end
      friends
    end

  end

end
