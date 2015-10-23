module Postoffice
	class QueueItem
		include Mongoid::Document
		include Mongoid::Timestamps

    field :person_id, type: BSON::ObjectId
    field :description, type: String
    field :status, type: String

    index({person_id: 1, description: 1}, { unique: true })
  end

end
