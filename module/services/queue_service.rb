module Postoffice

	class QueueService

    def self.log_action_occurrence description, person_id
      if Postoffice::QueueItem.where(description: description, person_id: person_id).exists?
        Postoffice::QueueItem.where(description: description, person_id: person_id).update(status: "DONE")
      else
        Postoffice::QueueItem.create!(description: description, person_id: person_id, status: "DONE")
      end
    end

    def self.action_has_occurred? description, person_id
      if Postoffice::QueueItem.where(description: description, person_id: person_id, status: "DONE").count > 0
        return true
      else
        return false
      end
    end

	end

end
