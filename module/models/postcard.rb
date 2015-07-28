module SnailMail

	class Postcard
    include Mongoid::Document
  	include Mongoid::Timestamps

    extend Dragonfly::Model
    dragonfly_accessor :image

    attr_accessor :image_uid

    field :image_uid, type: String

	end

end
