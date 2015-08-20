module Postoffice
	class Token
		include Mongoid::Document
		include Mongoid::Timestamps

		field :value, type: String
    field :is_invalid, type: Boolean

    index({ value: 1 }, { unique: true })

    def mark_as_invalid
      self.is_invalid = true
      self.save
    end

	end

end
