module Postoffice
	class Attachment
		include Mongoid::Document
		include Mongoid::Timestamps
    embedded_in :mail
  end

	class Note < Attachment
		field :content, type: String
	end

	class ImageAttachment < Attachment
		extend Dragonfly::Model
		dragonfly_accessor :image
		field :image_uid, type: String

		def url
			"#{ENV['POSTOFFICE_BASE_URL']}/image/#{self.image_uid}"
		end

	end

end
