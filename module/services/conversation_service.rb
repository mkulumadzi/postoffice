module Postoffice

  class ConversationService

    # Viw a list of the conversations a person has had, and include data such as
    ## The number of unread messages for the person
    ## The number of undelivered mail for the person
    ## The date of the most recent mail in the conversation (that the person is supposed to know about)

    def self.get_conversations_for_a_person person
      Postoffice::Conversation.where(people: person.id).to_a
    end

  end

end

# def self.conversation_metadata params
# 	penpals = self.get_contacts params
# 	conversations = []
# 	id = BSON::ObjectId(params[:id])
#
# 	penpals.each do |person|
#
# 		num_unread = Postoffice::Mail.where({from_person_id: person["_id"], "recipients.person_id" => id, status: "DELIVERED"}).count
# 		num_undelivered = Postoffice::Mail.where({from_person_id: id, "recipients.person_id" => person["_id"], status: "SENT"}).count
# 		all_mail_query = Postoffice::Mail.or({from_person_id: id, "recipients.person_id" => person["_id"]},{from_person_id: person["_id"], "recipients.person_id" => id, status: "DELIVERED"})
#
# 		most_recent_updated_mail = all_mail_query.sort! {|a,b| b[:updated_at] <=> a[:updated_at]}[0]
# 		most_recent_arrived_mail = all_mail_query.where(scheduled_to_arrive: {:$ne => nil}).sort! {|a,b| b[:scheduled_to_arrive] <=> a[:scheduled_to_arrive]}[0]
#
# 		metadata = Hash.new
# 		metadata[:person_id] = person["_id"]
# 		metadata[:username] = person["username"]
# 		metadata[:name] = person["name"]
# 		metadata[:num_unread] = num_unread
# 		metadata[:num_undelivered] = num_undelivered
# 		metadata[:updated_at] = most_recent_updated_mail[:updated_at]
# 		metadata[:most_recent_status] = most_recent_arrived_mail[:status]
# 		metadata[:most_recent_sender] = most_recent_arrived_mail[:from_person_id]
# 		conversations << metadata
#
# 	end
#
# 	conversations
# end
